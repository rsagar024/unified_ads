import 'package:flutter/services.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'messages.g.dart';

/// unified_ads adapter for Facebook Audience Network.
///
/// Registered automatically when `unified_ads_facebook` is a dependency of the
/// app; only the Facebook Audience Network SDK is linked. Setup: docs/setup/facebook.md.
///
/// `NetworkConfig.appId` is optional (Audience Network needs no app ID in code); ad-unit IDs are placement IDs (PLACEMENT_ID or the test form IMG_16_9_APP_INSTALL#PLACEMENT_ID).
/// Audience Network is bidding-only since 2021: a direct integration serves test ads but is not expected to fill in production (use AdMob / MAX / LevelPlay bidding for revenue). `testDeviceIds` are the hashed device IDs printed by the SDK.
class FacebookAdapter extends BridgedAdNetworkAdapter
    implements FacebookEventsApi {
  /// Creates the adapter. `hostApi` and `binaryMessenger` are for tests.
  FacebookAdapter({this._hostApi, this._messenger});

  /// Registers the adapter; called by Flutter's plugin registrant.
  static void registerWith() {
    AdapterRegistry.instance.register(FacebookAdapter());
  }

  /// Platform-view type of the native banner.
  static const viewType = 'dev.arovyx.plugin.unifiedads/facebook/banner';

  FacebookHostApi? _hostApi;
  final BinaryMessenger? _messenger;
  RewardItem _defaultReward = const RewardItem(amount: 1, type: 'reward');

  FacebookHostApi get _host =>
      _hostApi ??= FacebookHostApi(binaryMessenger: _messenger);

  @override
  AdNetwork get network => AdNetwork.facebook;

  @override
  Set<AdFormat> get supportedFormats => const {
    AdFormat.banner,
    AdFormat.interstitial,
    AdFormat.rewarded,
  };

  @override
  TestModeSupport get testModeSupport => TestModeSupport.testDevices;
  @override
  String get bannerViewType => viewType;

  @override
  Map<String, Object?> bannerCreationParams(BannerRequest request) => {
    'adId': request.adId,
    'adUnitId': request.adUnitId,
    'size': request.size.toMap(),
    'testMode': request.testMode,
  };

  @override
  void listenToNativeEvents() =>
      FacebookEventsApi.setUp(this, binaryMessenger: _messenger);

  @override
  Future<void> nativeInitialize(
    NetworkConfig config, {
    required bool testMode,
  }) {
    // Used when the SDK reports a reward without an amount or type.
    final amount = config.extras['rewardAmount'];
    final type = config.extras['rewardType'];
    _defaultReward = RewardItem(
      amount: amount is num ? amount : 1,
      type: type is String ? type : 'reward',
    );
    final userId = config.extras['userId'];
    return _host.initialize(
      InitRequest(
        appId: config.appId ?? '',
        testMode: testMode,
        testDeviceIds: config.testDeviceIds,
        userId: userId is String ? userId : null,
      ),
    );
  }

  @override
  Future<String> nativeLoad(AdFormat format, String adUnitId) => _host.load(
    format == AdFormat.rewarded
        ? AdFormatMessage.rewarded
        : AdFormatMessage.interstitial,
    adUnitId,
  );

  @override
  Future<void> nativeShow(String adId) => _host.show(adId);

  @override
  Future<void> nativeDestroy(String adId) => _host.destroy(adId);

  @override
  Future<void> nativeApplyConsent(ConsentState state) => _host.applyConsent(
    ConsentMessage(
      gdprApplies: state.gdprApplies,
      consentGiven: state.consentGiven,
      ccpaOptOut: state.ccpaOptOut,
      coppa: state.coppa,
    ),
  );

  @override
  Future<void> nativeDispose() => _host.dispose();

  /// Receives native events (Pigeon `FacebookEventsApi`). Not for app use.
  @override
  void onAdEvent(AdEventMessage event) {
    final isReward = event.kind == AdEventKind.earnedReward;
    emitNativeEvent(
      kind: event.kind.name,
      adId: event.adId,
      format: event.format.name,
      errorCode: event.errorCode,
      errorMessage: event.errorMessage,
      nativeCode: event.nativeCode,
      rewardAmount:
          event.rewardAmount ??
          (isReward ? _defaultReward.amount.toDouble() : null),
      rewardType: event.rewardType ?? (isReward ? _defaultReward.type : null),
      width: event.width,
      height: event.height,
    );
  }
}
