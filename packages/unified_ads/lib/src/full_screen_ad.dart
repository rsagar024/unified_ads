import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'guard.dart';
import 'runtime.dart';
import 'session.dart';

/// Callback receiving the ad object.
typedef AdCallback<T> = void Function(T ad);

/// Callback receiving the ad object and an error.
typedef AdErrorCallback<T> = void Function(T ad, AdError error);

/// Shared behaviour of full-screen ads ([format] is interstitial, rewarded,
/// …): waterfall loading, cache use, show guards and event callbacks.
///
/// An instance represents one ad at a time. After it is closed, call [load]
/// again (it completes immediately when a preloaded ad is cached).
abstract class FullScreenAd<T extends FullScreenAd<T>> {
  /// Creates the ad. [forceNetwork] bypasses the waterfall order.
  FullScreenAd(
    this.format, {
    this.forceNetwork,
    this.onLoaded,
    this.onFailedToLoad,
    this.onShown,
    this.onFailedToShow,
    this.onImpression,
    this.onClicked,
    this.onClosed,
  });

  /// The ad format.
  final AdFormat format;

  /// When set, only this network is tried.
  final AdNetwork? forceNetwork;

  /// Called when [load] succeeds.
  final AdCallback<T>? onLoaded;

  /// Called when [load] fails.
  final AdErrorCallback<T>? onFailedToLoad;

  /// Called when the ad is presented.
  final AdCallback<T>? onShown;

  /// Called when the ad cannot be shown.
  final AdErrorCallback<T>? onFailedToShow;

  /// Called when the network records an impression.
  final AdCallback<T>? onImpression;

  /// Called when the user clicks the ad.
  final AdCallback<T>? onClicked;

  /// Called when the ad is dismissed.
  final AdCallback<T>? onClosed;

  AdsSession? _session;
  AdHandle? _handle;
  StreamSubscription<AdEvent>? _subscription;
  AdNetwork? _servedBy;
  bool _consumed = false;
  bool _showing = false;
  bool _disposed = false;

  T get _self => this as T;

  /// The network that served the current (or last) ad.
  AdNetwork? get servedBy => _servedBy;

  /// Whether the ad is currently on screen.
  bool get isShowing => _showing;

  /// Whether a loaded, unexpired ad is ready to [show].
  bool get isReady {
    final session = _session;
    final handle = _handle;
    if (_disposed || _consumed || session == null || handle == null) {
      return false;
    }
    if (!identical(session, AdsRuntime.instance.session)) return false;
    return session.isHandleReady(handle);
  }

  /// Loads an ad through the waterfall (or takes a preloaded one).
  ///
  /// Completes immediately with success if an ad is already ready.
  Future<AdResult<void>> load() async {
    if (_disposed) {
      return _loadFailed(_error(AdErrorCode.notReady, 'ad was disposed'));
    }
    final session = AdsRuntime.instance.session;
    if (session == null || !AdsRuntime.instance.isInitialized) {
      return _loadFailed(
        _error(AdErrorCode.notInitialized, 'Call UnifiedAds.init first'),
      );
    }
    if (_showing) {
      return _loadFailed(
        _error(AdErrorCode.alreadyShowing, 'ad is currently showing'),
      );
    }
    if (isReady) return const AdSuccess(null);

    await _release();
    final result = await session.acquire(format, force: forceNetwork);
    switch (result) {
      case AdSuccess(:final value):
        if (_disposed || session.isDisposed) {
          await session.destroy(value);
          return _loadFailed(_error(AdErrorCode.notReady, 'ad was disposed'));
        }
        _attach(session, value);
        safeCallback('onLoaded', () => onLoaded?.call(_self));
        return const AdSuccess(null);
      case AdFailure(:final error):
        return _loadFailed(error);
    }
  }

  /// Shows the loaded ad.
  ///
  /// Fails with [AdErrorCode.notInitialized], [AdErrorCode.notReady],
  /// [AdErrorCode.alreadyShowing] or [AdErrorCode.frequencyCapped] without
  /// contacting the network. Completes when the ad is presented, not when it
  /// is closed; use the `onClosed` callback for that.
  Future<AdResult<void>> show() async {
    if (AdsRuntime.instance.session == null) {
      return _showFailed(
        _error(AdErrorCode.notInitialized, 'Call UnifiedAds.init first'),
      );
    }
    final session = _session;
    final handle = _handle;
    if (session == null || handle == null || !isReady) {
      return _showFailed(
        _error(AdErrorCode.notReady, 'No loaded ad; call load() first'),
      );
    }
    if (session.fullScreenShowing) {
      return _showFailed(
        _error(AdErrorCode.alreadyShowing, 'another full-screen ad is showing'),
      );
    }
    if (!await session.frequency.canShow(format)) {
      return _showFailed(
        _error(
          AdErrorCode.frequencyCapped,
          '${format.id} frequency cap reached',
        ),
      );
    }

    session.fullScreenShowing = true;
    _showing = true;
    final result = await session.show(handle);
    switch (result) {
      case AdSuccess():
        await session.frequency.record(format);
        return result;
      case AdFailure(:final error):
        // An AdFailedToShow event may already have finished the show.
        if (!_showing) return result;
        _finishShow();
        return _showFailed(error);
    }
  }

  /// Releases the ad. The object cannot be used afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _release();
  }

  /// Hook for subclasses: called when the user earned a reward.
  @protected
  void handleEarnedReward(RewardItem reward) {}

  void _attach(AdsSession session, AdHandle handle) {
    _session = session;
    _handle = handle;
    _servedBy = handle.network;
    _consumed = false;
    _subscription = session.events
        .where((e) => e.network == handle.network && e.adId == handle.id)
        .listen(_onEvent);
  }

  Future<void> _release() async {
    await _subscription?.cancel();
    _subscription = null;
    final session = _session;
    final handle = _handle;
    _handle = null;
    if (session != null && handle != null && !_consumed && !_showing) {
      await session.destroy(handle);
    }
  }

  void _onEvent(AdEvent event) {
    switch (event) {
      case AdShown():
        safeCallback('onShown', () => onShown?.call(_self));
      case AdImpression():
        safeCallback('onImpression', () => onImpression?.call(_self));
      case AdClicked():
        safeCallback('onClicked', () => onClicked?.call(_self));
      case AdEarnedReward(:final reward):
        handleEarnedReward(reward);
      case AdClosed():
        if (!_showing) return;
        _finishShow();
        safeCallback('onClosed', () => onClosed?.call(_self));
      case AdFailedToShow(:final error):
        if (!_showing) return;
        _finishShow();
        _showFailed(error);
      case AdLoaded() || AdFailedToLoad() || BannerSized():
        break;
    }
  }

  void _finishShow() {
    _showing = false;
    _consumed = true;
    final session = _session;
    if (session == null || session.isDisposed) return;
    session.fullScreenShowing = false;
    unawaited(session.refillIfEnabled(format));
  }

  AdError _error(AdErrorCode code, String message) =>
      AdError(code: code, message: message, network: forceNetwork);

  AdResult<void> _loadFailed(AdError error) {
    safeCallback('onFailedToLoad', () => onFailedToLoad?.call(_self, error));
    return AdFailure(error);
  }

  AdResult<void> _showFailed(AdError error) {
    safeCallback('onFailedToShow', () => onFailedToShow?.call(_self, error));
    return AdFailure(error);
  }
}
