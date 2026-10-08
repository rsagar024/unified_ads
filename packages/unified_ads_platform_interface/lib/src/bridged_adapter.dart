import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ad_error.dart';
import 'ad_event.dart';
import 'ad_format.dart';
import 'ad_handle.dart';
import 'ad_network_adapter.dart';
import 'ad_result.dart';
import 'ads_logger.dart';
import 'consent.dart';
import 'network_config.dart';
import 'reward_item.dart';

/// Base class for adapters whose native side is reached through a Pigeon (or
/// method-channel) host API.
///
/// It implements the [AdNetworkAdapter] contract (never throwing, error
/// mapping, loaded-ad tracking for a synchronous [isReady], the event stream)
/// so a concrete adapter only bridges six native calls and forwards native
/// events to [emitNativeEvent].
///
/// Native failures must be platform errors whose `code` is an [AdErrorCode]
/// name and whose `details` is the SDK's own error code.
abstract class BridgedAdNetworkAdapter extends AdNetworkAdapter {
  /// Allows subclasses to call `super()`.
  BridgedAdNetworkAdapter();

  final StreamController<AdEvent> _events = StreamController.broadcast();
  final Map<String, AdHandle> _loaded = {};
  bool _listening = false;

  /// Formats loaded with [load] (the full-screen subset of
  /// [supportedFormats]).
  Set<AdFormat> get fullScreenFormats =>
      supportedFormats.where((f) => f.isFullScreen).toSet();

  /// Starts receiving native events. Called once, before the first
  /// [nativeInitialize] (the Flutter binding exists by then).
  @protected
  void listenToNativeEvents();

  /// Initializes the native SDK.
  @protected
  Future<void> nativeInitialize(NetworkConfig config, {required bool testMode});

  /// Loads a full-screen ad and returns the native ad id.
  @protected
  Future<String> nativeLoad(AdFormat format, String adUnitId);

  /// Shows a loaded ad; completes when it is presented.
  @protected
  Future<void> nativeShow(String adId);

  /// Releases a loaded ad.
  @protected
  Future<void> nativeDestroy(String adId);

  /// Forwards privacy signals to the native SDK.
  @protected
  Future<void> nativeApplyConsent(ConsentState state);

  /// Releases every native ad.
  @protected
  Future<void> nativeDispose();

  @override
  Future<AdResult<void>> initialize(
    NetworkConfig config, {
    required bool testMode,
  }) async {
    if (!_listening) {
      _listening = true;
      listenToNativeEvents();
    }
    try {
      await nativeInitialize(config, testMode: testMode);
      return const AdSuccess(null);
    } on PlatformException catch (e) {
      return AdFailure(_error(e, AdErrorCode.initializationFailed));
    }
  }

  @override
  Future<AdResult<AdHandle>> load(AdFormat format, String adUnitId) async {
    if (!fullScreenFormats.contains(format)) {
      return AdFailure(
        AdError(
          code: AdErrorCode.unsupportedFormat,
          message:
              '${network.displayName} cannot load ${format.id} as a '
              'full-screen ad',
          network: network,
        ),
      );
    }
    try {
      final id = await nativeLoad(format, adUnitId);
      final handle = AdHandle(
        id: id,
        network: network,
        format: format,
        adUnitId: adUnitId,
        loadedAt: DateTime.now(),
      );
      _loaded[id] = handle;
      return AdSuccess(handle);
    } on PlatformException catch (e) {
      return AdFailure(_error(e, AdErrorCode.internal));
    }
  }

  @override
  Future<AdResult<void>> show(AdHandle handle) async {
    if (_loaded.remove(handle.id) == null) {
      return AdFailure(
        AdError(
          code: AdErrorCode.notReady,
          message: 'Ad ${handle.id} is not loaded',
          network: network,
        ),
      );
    }
    try {
      await nativeShow(handle.id);
      return const AdSuccess(null);
    } on PlatformException catch (e) {
      return AdFailure(_error(e, AdErrorCode.showFailed));
    }
  }

  @override
  bool isReady(AdHandle handle) => _loaded.containsKey(handle.id);

  @override
  Future<void> destroy(AdHandle handle) async {
    _loaded.remove(handle.id);
    try {
      await nativeDestroy(handle.id);
    } on PlatformException catch (e) {
      AdsLogger.current.debug('destroy failed: ${e.message}', network: network);
    }
  }

  @override
  Future<void> applyConsent(ConsentState state) async {
    try {
      await nativeApplyConsent(state);
    } on PlatformException catch (e) {
      AdsLogger.current.warning(
        'applyConsent failed',
        network: network,
        error: e,
      );
    }
  }

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  Future<void> dispose() async {
    _loaded.clear();
    try {
      await nativeDispose();
    } on PlatformException catch (e) {
      AdsLogger.current.debug('dispose failed: ${e.message}', network: network);
    }
  }

  /// Logs whether the app added the opt-in Meta (Facebook) bidding adapter for
  /// this mediation network; [adapterClass] is the class the native side
  /// detected, or null. Used by the AdMob, AppLovin MAX and LevelPlay adapters.
  @protected
  void logMetaBidding(String? adapterClass) {
    if (adapterClass == null) {
      AdsLogger.current.debug(
        'Meta bidding adapter not present (opt-in; see doc/setup)',
        network: network,
      );
    } else {
      AdsLogger.current.info(
        'Meta bidding adapter detected ($adapterClass)',
        network: network,
      );
    }
  }

  /// Converts a native event into an [AdEvent] and publishes it.
  ///
  /// [kind] is an event name (`loaded`, `failedToLoad`, `failedToShow`,
  /// `shown`, `impression`, `clicked`, `closed`, `earnedReward`,
  /// `bannerSized`) and [format] an [AdFormat] id. Unknown values are logged
  /// and dropped.
  void emitNativeEvent({
    required String kind,
    required String adId,
    required String format,
    String? errorCode,
    String? errorMessage,
    String? nativeCode,
    double? rewardAmount,
    String? rewardType,
    double? width,
    double? height,
  }) {
    final adFormat = AdFormat.tryParse(format);
    if (adFormat == null) {
      AdsLogger.current.warning(
        'unknown native format $format',
        network: network,
      );
      return;
    }
    AdError error() => AdError(
      code: errorCodeFromName(errorCode, AdErrorCode.internal),
      message: errorMessage ?? '${network.displayName} error',
      network: network,
      nativeCode: nativeCode,
    );
    final AdEvent? event = switch (kind) {
      'loaded' => AdLoaded(network: network, adId: adId, format: adFormat),
      'failedToLoad' => AdFailedToLoad(
        network: network,
        adId: adId,
        format: adFormat,
        error: error(),
      ),
      'failedToShow' => AdFailedToShow(
        network: network,
        adId: adId,
        format: adFormat,
        error: error(),
      ),
      'shown' => AdShown(network: network, adId: adId, format: adFormat),
      'impression' => AdImpression(
        network: network,
        adId: adId,
        format: adFormat,
      ),
      'clicked' => AdClicked(network: network, adId: adId, format: adFormat),
      'closed' => AdClosed(network: network, adId: adId, format: adFormat),
      'earnedReward' => AdEarnedReward(
        network: network,
        adId: adId,
        format: adFormat,
        reward: RewardItem(amount: rewardAmount ?? 0, type: rewardType ?? ''),
      ),
      'bannerSized' => BannerSized(
        network: network,
        adId: adId,
        width: width ?? 0,
        height: height ?? 0,
      ),
      _ => null,
    };
    if (event == null) {
      AdsLogger.current.warning('unknown native event $kind', network: network);
      return;
    }
    if (event is AdClosed || event is AdFailedToShow) _loaded.remove(adId);
    _events.add(event);
  }

  AdError _error(PlatformException e, AdErrorCode fallback) => AdError(
    code: errorCodeFromName(e.code, fallback),
    message: e.message ?? e.code,
    network: network,
    nativeCode: e.details?.toString(),
  );

  /// The [AdErrorCode] whose name is [name], or [fallback].
  static AdErrorCode errorCodeFromName(String? name, AdErrorCode fallback) =>
      AdErrorCode.values.asNameMap()[name] ?? fallback;
}
