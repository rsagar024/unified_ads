import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'guard.dart';
import 'runtime.dart';
import 'session.dart';
import 'waterfall.dart';

/// Lifecycle state of a [BannerAd].
enum BannerAdState {
  /// Not loaded yet.
  idle,

  /// Trying networks.
  loading,

  /// A network filled the banner.
  loaded,

  /// Every network failed; see [BannerAd.error].
  failed,

  /// [BannerAd.dispose] was called.
  disposed,
}

/// The native banner view currently being created or displayed.
@immutable
class BannerAttempt {
  /// Creates an attempt.
  const BannerAttempt({
    required this.network,
    required this.adId,
    required this.viewType,
    required this.creationParams,
  });

  /// Network that renders this view.
  final AdNetwork network;

  /// Identifier of the banner in adapter events.
  final String adId;

  /// Platform-view type registered by the adapter.
  final String viewType;

  /// Parameters for the native view factory.
  final Map<String, Object?> creationParams;
}

/// A banner ad. Display it with `UnifiedBannerWidget`, which also starts
/// loading it.
///
/// The banner walks the waterfall: each network gets a native view; if it
/// fails (or times out) the view is replaced by the next network's.
class BannerAd extends ChangeNotifier {
  /// Creates a banner. [forceNetwork] bypasses the waterfall order.
  BannerAd({
    this.size = const BannerSize.adaptiveAnchored(),
    this.forceNetwork,
    this.onLoaded,
    this.onFailedToLoad,
    this.onImpression,
    this.onClicked,
  });

  /// Requested size.
  final BannerSize size;

  /// When set, only this network is tried.
  final AdNetwork? forceNetwork;

  /// Called when a network fills the banner.
  final void Function(BannerAd ad)? onLoaded;

  /// Called when every network failed.
  final void Function(BannerAd ad, AdError error)? onFailedToLoad;

  /// Called when the network records an impression.
  final void Function(BannerAd ad)? onImpression;

  /// Called when the user clicks the banner.
  final void Function(BannerAd ad)? onClicked;

  BannerAdState _state = BannerAdState.idle;
  BannerAttempt? _current;
  AdNetwork? _servedBy;
  AdError? _error;
  Size? _adSize;
  AdsSession? _session;
  StreamSubscription<AdEvent>? _subscription;
  Timer? _timeout;
  List<WaterfallCandidate> _queue = const [];
  final List<AdError> _attempts = [];
  Completer<AdResult<void>>? _completer;
  double? _width;

  /// Current state.
  BannerAdState get state => _state;

  /// The native view to display, if any.
  BannerAttempt? get current => _current;

  /// The network that filled the banner.
  AdNetwork? get servedBy => _servedBy;

  /// Why loading failed, when [state] is [BannerAdState.failed].
  AdError? get error => _error;

  /// Size reported by the network, once known.
  Size? get adSize => _adSize;

  /// Starts loading. [width] is the available width for adaptive sizes.
  ///
  /// The returned future completes when a network fills the banner or all
  /// fail. A native view only loads while it is displayed by
  /// `UnifiedBannerWidget`.
  Future<AdResult<void>> load({double? width}) {
    if (_state == BannerAdState.disposed) {
      return Future.value(
        const AdFailure(
          AdError(code: AdErrorCode.notReady, message: 'banner was disposed'),
        ),
      );
    }
    final pending = _completer;
    if (_state == BannerAdState.loading && pending != null) {
      return pending.future;
    }
    final session = AdsRuntime.instance.session;
    if (session == null || !AdsRuntime.instance.isInitialized) {
      return Future.value(
        _finish(
          AdFailure(
            AdError(
              code: AdErrorCode.notInitialized,
              message: 'Call UnifiedAds.init first',
              network: forceNetwork,
            ),
          ),
        ),
      );
    }
    if (!identical(session, _session)) {
      unawaited(_subscription?.cancel());
      _session = session;
      _subscription = session.events.listen(_onEvent);
    }
    _width = width;
    _attempts.clear();
    final (:candidates, :skipped) = session.waterfall.plan(
      AdFormat.banner,
      force: forceNetwork,
    );
    if (candidates.isEmpty) {
      return Future.value(
        _finish(
          AdFailure(
            skipped.length == 1
                ? skipped.single
                : AdError(
                    code: AdErrorCode.noFill,
                    message: 'No initialized network can serve banners',
                    attempts: skipped,
                  ),
          ),
        ),
      );
    }
    _queue = List.of(candidates);
    _state = BannerAdState.loading;
    _error = null;
    final completer = _completer = Completer<AdResult<void>>();
    _next();
    return completer.future;
  }

  void _next() {
    _timeout?.cancel();
    final session = _session;
    if (_queue.isEmpty || session == null || session.isDisposed) {
      _current = null;
      final error = _attempts.length == 1
          ? _attempts.single
          : AdError(
              code: AdErrorCode.noFill,
              message:
                  'All ${_attempts.length} networks failed to load a banner',
              attempts: List.of(_attempts),
            );
      _finish(AdFailure(error));
      return;
    }
    final (:network, :adUnitId) = _queue.removeAt(0);
    final adapter = session.adapterFor(network);
    if (adapter == null) {
      _attempts.add(
        AdError(
          code: AdErrorCode.notInitialized,
          message: '${network.id} is no longer initialized',
          network: network,
        ),
      );
      _next();
      return;
    }
    final width = _width;
    final request = BannerRequest(
      adId: session.nextAdId(network, AdFormat.banner),
      adUnitId: adUnitId,
      size: width == null ? size : size.withWidth(width),
      testMode: session.config.isTestMode(network),
    );
    final params = guardSync<Map<String, Object?>?>(
      network,
      'bannerCreationParams',
      null,
      () => adapter.bannerCreationParams(request),
    );
    if (params == null) {
      _attempts.add(
        AdError(
          code: AdErrorCode.internal,
          message: 'adapter failed to create banner parameters',
          network: network,
        ),
      );
      _next();
      return;
    }
    _current = BannerAttempt(
      network: network,
      adId: request.adId,
      viewType: adapter.bannerViewType,
      creationParams: params,
    );
    _timeout = Timer(session.config.loadTimeout, () {
      _attemptFailed(
        AdError(
          code: AdErrorCode.timeout,
          message: 'banner load timed out',
          network: network,
        ),
      );
    });
    notifyListeners();
  }

  void _onEvent(AdEvent event) {
    final attempt = _current;
    if (attempt == null ||
        event.adId != attempt.adId ||
        event.network != attempt.network) {
      return;
    }
    switch (event) {
      case AdLoaded():
        if (_state != BannerAdState.loading) return;
        _timeout?.cancel();
        _servedBy = attempt.network;
        _finish(const AdSuccess(null));
      case AdFailedToLoad(:final error):
        if (_state == BannerAdState.loading) {
          _attemptFailed(error);
        } else {
          AdsLogger.current.debug(
            'banner refresh failed: ${error.message}',
            network: event.network,
          );
        }
      case BannerSized(:final width, :final height):
        _adSize = Size(width, height);
        notifyListeners();
      case AdImpression():
        safeCallback('onImpression', () => onImpression?.call(this));
      case AdClicked():
        safeCallback('onClicked', () => onClicked?.call(this));
      case AdShown() || AdClosed() || AdFailedToShow() || AdEarnedReward():
        break;
    }
  }

  void _attemptFailed(AdError error) {
    if (_state != BannerAdState.loading) return;
    _attempts.add(error);
    _current = null;
    _adSize = null;
    _next();
  }

  AdResult<void> _finish(AdResult<void> result) {
    _timeout?.cancel();
    switch (result) {
      case AdSuccess():
        _state = BannerAdState.loaded;
        safeCallback('onLoaded', () => onLoaded?.call(this));
      case AdFailure(:final error):
        _state = BannerAdState.failed;
        _error = error;
        _current = null;
        safeCallback('onFailedToLoad', () => onFailedToLoad?.call(this, error));
    }
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) completer.complete(result);
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    if (_state == BannerAdState.disposed) return;
    _state = BannerAdState.disposed;
    _timeout?.cancel();
    unawaited(_subscription?.cancel());
    _current = null;
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        const AdFailure(
          AdError(code: AdErrorCode.notReady, message: 'banner was disposed'),
        ),
      );
    }
    super.dispose();
  }
}
