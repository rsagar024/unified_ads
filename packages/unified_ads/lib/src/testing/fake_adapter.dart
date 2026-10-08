import 'dart:async';
import 'dart:ui' show Size;

import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

/// A scriptable in-memory [AdNetworkAdapter] for tests.
///
/// Configure behaviour through the mutable fields (they may be changed
/// between calls) and inspect the recorded calls afterwards.
///
/// ```dart
/// final admob = FakeAdNetworkAdapter(AdNetwork.admob)..loadError = noFill;
/// await UnifiedAds.init(config, adapters: [admob]);
/// ```
class FakeAdNetworkAdapter extends AdNetworkAdapter {
  /// Creates a fake for [network] supporting banner, interstitial and
  /// rewarded unless [supportedFormats] says otherwise.
  FakeAdNetworkAdapter(
    this.network, {
    Set<AdFormat>? supportedFormats,
    this.testModeSupport = TestModeSupport.flag,
    this.requiresAdUnitId = true,
    this.initError,
    this.initDelay = Duration.zero,
    this.loadError,
    this.loadDelay = Duration.zero,
    this.showError,
    this.reward = const RewardItem(amount: 10, type: 'coins'),
    this.autoCloseOnShow = false,
    this.bannerError,
    this.bannerSize = const Size(320, 50),
    this.respondToBanners = true,
  }) : supportedFormats =
           supportedFormats ??
           const {AdFormat.banner, AdFormat.interstitial, AdFormat.rewarded};

  @override
  final AdNetwork network;

  @override
  final Set<AdFormat> supportedFormats;

  @override
  final TestModeSupport testModeSupport;

  @override
  final bool requiresAdUnitId;

  /// When set, [initialize] fails with this error.
  AdError? initError;

  /// Delay before [initialize] completes.
  Duration initDelay;

  /// When set, [load] fails with this error.
  AdError? loadError;

  /// Delay before [load] completes.
  Duration loadDelay;

  /// When set, [show] fails with this error.
  AdError? showError;

  /// Reward emitted when a rewarded ad is shown.
  RewardItem reward;

  /// Whether [show] also emits a closed event.
  bool autoCloseOnShow;

  /// When set, banners fail with this error.
  AdError? bannerError;

  /// Size reported for banners.
  Size bannerSize;

  /// Whether banners answer automatically (in a microtask) after their
  /// creation parameters are requested.
  bool respondToBanners;

  /// Number of [initialize] calls.
  int initializeCalls = 0;

  /// Config passed to the last [initialize] call.
  NetworkConfig? lastConfig;

  /// Test-mode flag passed to the last [initialize] call.
  bool? lastTestMode;

  /// Every [load] call.
  final List<({AdFormat format, String adUnitId})> loadCalls = [];

  /// Handles passed to successful [show] calls.
  final List<AdHandle> shown = [];

  /// Handles passed to [destroy].
  final List<AdHandle> destroyed = [];

  /// Consent states received.
  final List<ConsentState> consents = [];

  /// Banner requests received.
  final List<BannerRequest> bannerRequests = [];

  /// Number of [dispose] calls.
  int disposeCalls = 0;

  final StreamController<AdEvent> _events = StreamController.broadcast();
  final Map<String, AdHandle> _loaded = {};
  int _counter = 0;

  @override
  Future<AdResult<void>> initialize(
    NetworkConfig config, {
    required bool testMode,
  }) async {
    initializeCalls++;
    lastConfig = config;
    lastTestMode = testMode;
    if (initDelay > Duration.zero) await Future<void>.delayed(initDelay);
    final error = initError;
    if (error != null) return AdFailure(error.copyWith(network: network));
    return const AdSuccess(null);
  }

  @override
  Future<AdResult<AdHandle>> load(AdFormat format, String adUnitId) async {
    loadCalls.add((format: format, adUnitId: adUnitId));
    if (loadDelay > Duration.zero) await Future<void>.delayed(loadDelay);
    if (!supportedFormats.contains(format)) {
      return AdFailure(
        AdError(
          code: AdErrorCode.unsupportedFormat,
          message: 'fake does not support ${format.id}',
          network: network,
        ),
      );
    }
    final error = loadError;
    if (error != null) return AdFailure(error.copyWith(network: network));
    final handle = AdHandle(
      id: '${network.id}-${++_counter}',
      network: network,
      format: format,
      adUnitId: adUnitId,
      loadedAt: DateTime.now(),
    );
    _loaded[handle.id] = handle;
    emit(AdLoaded(network: network, adId: handle.id, format: format));
    return AdSuccess(handle);
  }

  @override
  Future<AdResult<void>> show(AdHandle handle) async {
    if (!isReady(handle)) {
      return AdFailure(
        AdError(
          code: AdErrorCode.notReady,
          message: 'fake ad not loaded',
          network: network,
        ),
      );
    }
    final error = showError;
    if (error != null) return AdFailure(error.copyWith(network: network));
    _loaded.remove(handle.id);
    shown.add(handle);
    emit(AdShown(network: network, adId: handle.id, format: handle.format));
    emit(
      AdImpression(network: network, adId: handle.id, format: handle.format),
    );
    if (handle.format.isRewarded) {
      emit(
        AdEarnedReward(
          network: network,
          adId: handle.id,
          format: handle.format,
          reward: reward,
        ),
      );
    }
    if (autoCloseOnShow) simulateClose(handle);
    return const AdSuccess(null);
  }

  @override
  bool isReady(AdHandle handle) => _loaded.containsKey(handle.id);

  @override
  Future<void> destroy(AdHandle handle) async {
    destroyed.add(handle);
    _loaded.remove(handle.id);
  }

  @override
  String get bannerViewType => 'fake/${network.id}/banner';

  @override
  Map<String, Object?> bannerCreationParams(BannerRequest request) {
    bannerRequests.add(request);
    if (respondToBanners) {
      scheduleMicrotask(() => respondToBanner(request.adId));
    }
    return {
      'adId': request.adId,
      'adUnitId': request.adUnitId,
      'size': request.size.toMap(),
    };
  }

  /// Emits the configured banner outcome for [adId] (loaded + sized, or
  /// failed).
  void respondToBanner(String adId) {
    final error = bannerError;
    if (error != null) {
      emit(
        AdFailedToLoad(
          network: network,
          adId: adId,
          format: AdFormat.banner,
          error: error.copyWith(network: network),
        ),
      );
      return;
    }
    emit(
      BannerSized(
        network: network,
        adId: adId,
        width: bannerSize.width,
        height: bannerSize.height,
      ),
    );
    emit(AdLoaded(network: network, adId: adId, format: AdFormat.banner));
  }

  @override
  Future<void> applyConsent(ConsentState state) async => consents.add(state);

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _loaded.clear();
  }

  /// Emits [event] on [events].
  void emit(AdEvent event) => _events.add(event);

  /// Emits a click for [handle].
  void simulateClick(AdHandle handle) =>
      emit(AdClicked(network: network, adId: handle.id, format: handle.format));

  /// Emits a close for [handle].
  void simulateClose(AdHandle handle) =>
      emit(AdClosed(network: network, adId: handle.id, format: handle.format));
}
