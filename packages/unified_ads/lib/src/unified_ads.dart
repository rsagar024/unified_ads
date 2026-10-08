import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'frequency.dart';
import 'init_result.dart';
import 'runtime.dart';

/// Entry point of unified_ads.
///
/// ```dart
/// final result = await UnifiedAds.init(AdConfig(
///   testMode: true,
///   waterfall: [AdNetwork.admob, AdNetwork.unity],
///   networks: {AdNetwork.admob: NetworkConfig(appId: '…', interstitialAdUnitId: '…')},
/// ));
/// ```
///
/// Calling [init] again (for example after the user changes settings or on
/// hot restart) disposes the previous session first.
abstract final class UnifiedAds {
  static AdsRuntime get _runtime => AdsRuntime.instance;

  /// Initializes every enabled network in [config] that has an adapter.
  ///
  /// Adapters register themselves when their package is a dependency;
  /// [adapters] registers additional ones explicitly (and overrides
  /// registered adapters of the same network). [consent] is applied to every
  /// adapter before its SDK initializes. [frequencyStore] persists frequency
  /// caps (in memory by default).
  ///
  /// Never throws: per-network problems are reported in the returned
  /// [InitResult].
  static Future<InitResult> init(
    AdConfig config, {
    List<AdNetworkAdapter> adapters = const [],
    ConsentState? consent,
    FrequencyStore? frequencyStore,
  }) => _runtime.init(
    config,
    adapters: adapters,
    consent: consent,
    frequencyStore: frequencyStore,
  );

  /// Whether [init] completed with at least one ready network.
  static bool get isInitialized => _runtime.isInitialized;

  /// The active configuration, or `null` before [init].
  static AdConfig? get config => _runtime.session?.config;

  /// Result of the most recent [init].
  static InitResult? get lastInitResult => _runtime.lastInitResult;

  /// Networks that can currently serve ads.
  static Set<AdNetwork> get readyNetworks =>
      _runtime.session?.readyNetworks ?? const {};

  /// Every ad event of every network. The stream survives re-initialization.
  static Stream<AdEvent> get events => _runtime.events;

  /// The logger used by unified_ads and its adapters. Silent by default.
  static AdsLogger get logger => AdsLogger.current;

  static set logger(AdsLogger logger) => AdsLogger.current = logger;

  /// The consent state currently applied.
  static ConsentState get consent => _runtime.consent;

  /// Applies [state] to every adapter (and to future sessions).
  static Future<void> updateConsent(ConsentState state) =>
      _runtime.updateConsent(state);

  /// Runs [provider]'s consent flow and applies the result. On failure the
  /// previous state is kept and returned.
  ///
  /// App-level signals a CMP cannot know are preserved: `coppa` stays set if
  /// it was set before, and `ccpaOptOut` is kept when the provider reports
  /// none.
  static Future<ConsentState> gatherConsent(
    ConsentProvider provider, {
    bool forceForm = false,
  }) async {
    final ConsentState state;
    try {
      state = await provider.gather(forceForm: forceForm);
    } catch (e, st) {
      AdsLogger.current.error(
        'consent gathering failed',
        error: e,
        stackTrace: st,
      );
      return _runtime.consent;
    }
    final previous = _runtime.consent;
    final merged = state.copyWith(
      ccpaOptOut: state.ccpaOptOut ?? previous.ccpaOptOut,
      coppa: state.coppa || previous.coppa,
    );
    await updateConsent(merged);
    return merged;
  }

  /// Loads a full-screen ad of [format] into the cache, so the next `load()`
  /// completes immediately.
  static Future<AdResult<void>> preload(AdFormat format) async {
    final session = _runtime.session;
    if (session == null || !_runtime.isInitialized) {
      return const AdFailure(
        AdError(
          code: AdErrorCode.notInitialized,
          message: 'Call UnifiedAds.init first',
        ),
      );
    }
    if (!format.isFullScreen) {
      return AdFailure(
        AdError(
          code: AdErrorCode.unsupportedFormat,
          message: '${format.id} cannot be preloaded',
        ),
      );
    }
    return session.refill(format);
  }

  /// Whether a preloaded ad of [format] is cached.
  static bool hasCachedAd(AdFormat format) =>
      _runtime.session?.cache.has(format) ?? false;

  /// Shows the App Tracking Transparency prompt on iOS if it has not been
  /// shown yet, and returns the resulting status. Returns
  /// [TrackingStatus.notApplicable] on Android.
  ///
  /// Call it before [init] (and before gathering consent) so SDKs see the
  /// final status. Requires `NSUserTrackingUsageDescription` in Info.plist.
  static Future<TrackingStatus> requestTrackingAuthorization() async {
    try {
      return await _runtime.tracking.request();
    } catch (e) {
      AdsLogger.current.warning('tracking request failed', error: e);
      return TrackingStatus.unavailable;
    }
  }

  /// The current App Tracking Transparency status, without prompting.
  static Future<TrackingStatus> trackingAuthorizationStatus() async {
    try {
      return await _runtime.tracking.status();
    } catch (e) {
      AdsLogger.current.warning('tracking status failed', error: e);
      return TrackingStatus.unavailable;
    }
  }

  /// Disposes every adapter and cached ad. [init] may be called again later.
  static Future<void> dispose() => _runtime.dispose();
}
