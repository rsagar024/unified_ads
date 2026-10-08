import 'package:flutter/services.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'messages.g.dart';

/// unified_ads adapter for AppLovin MAX.
///
/// Registered automatically when `unified_ads_applovin` is a dependency of the
/// app; only the AppLovin MAX SDK is linked. Setup: doc/setup/applovin.md.
///
/// `NetworkConfig.appId` is the MAX SDK key. Formats: banner, interstitial,
/// rewarded and app open (MAX has no rewarded interstitial).
///
/// Meta (Facebook) bidding is opt-in: add AppLovin's Meta adapter to the app's
/// build and this adapter detects it and forwards privacy settings.
/// Test mode registers `NetworkConfig.testDeviceIds` (GAID / IDFA) as MAX test devices. MAX must not be initialized for child-directed users (COPPA).
class ApplovinAdapter extends BridgedAdNetworkAdapter
    implements ApplovinEventsApi {
  /// Creates the adapter. `hostApi` and `binaryMessenger` are for tests.
  ApplovinAdapter({this._hostApi, this._messenger});

  /// Registers the adapter; called by Flutter's plugin registrant.
  static void registerWith() {
    AdapterRegistry.instance.register(ApplovinAdapter());
  }

  /// Platform-view type of the native banner.
  static const viewType = 'dev.arovyx.plugin.unifiedads/applovin/banner';

  ApplovinHostApi? _hostApi;
  final BinaryMessenger? _messenger;
  RewardItem _defaultReward = const RewardItem(amount: 1, type: 'reward');

  ApplovinHostApi get _host =>
      _hostApi ??= ApplovinHostApi(binaryMessenger: _messenger);

  @override
  AdNetwork get network => AdNetwork.applovin;

  @override
  Set<AdFormat> get supportedFormats => const {
    AdFormat.banner,
    AdFormat.interstitial,
    AdFormat.rewarded,
    AdFormat.appOpen,
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
      ApplovinEventsApi.setUp(this, binaryMessenger: _messenger);

  @override
  Future<void> nativeInitialize(
    NetworkConfig config, {
    required bool testMode,
  }) async {
    // Used when the SDK reports a reward without an amount or type.
    final amount = config.extras['rewardAmount'];
    final type = config.extras['rewardType'];
    _defaultReward = RewardItem(
      amount: amount is num ? amount : 1,
      type: type is String ? type : 'reward',
    );
    final userId = config.extras['userId'];
    final info = await _host.initialize(
      InitRequest(
        appId: config.appId ?? '',
        testMode: testMode,
        testDeviceIds: config.testDeviceIds,
        userId: userId is String ? userId : null,
      ),
    );
    logMetaBidding(info.metaBiddingAdapter);
  }

  @override
  Future<String> nativeLoad(AdFormat format, String adUnitId) =>
      _host.load(switch (format) {
        AdFormat.banner => AdFormatMessage.banner,
        AdFormat.interstitial => AdFormatMessage.interstitial,
        AdFormat.rewarded => AdFormatMessage.rewarded,
        AdFormat.appOpen => AdFormatMessage.appOpen,
        // Not in supportedFormats, so the base class never asks for it.
        AdFormat.rewardedInterstitial => throw ArgumentError.value(format),
      }, adUnitId);

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

  /// Receives native events (Pigeon `ApplovinEventsApi`). Not for app use.
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
