import 'package:flutter/services.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'messages.g.dart';

/// unified_ads adapter for InMobi.
///
/// Registered automatically when `unified_ads_inmobi` is a dependency of the
/// app; only the InMobi SDK is linked. Setup: docs/setup/inmobi.md.
///
/// `NetworkConfig.appId` is the InMobi account ID; ad-unit IDs are numeric InMobi placement IDs.
/// InMobi test ads can only be enabled per placement in the InMobi dashboard.
class InmobiAdapter extends BridgedAdNetworkAdapter implements InmobiEventsApi {
  /// Creates the adapter. `hostApi` and `binaryMessenger` are for tests.
  InmobiAdapter({this._hostApi, this._messenger});

  /// Registers the adapter; called by Flutter's plugin registrant.
  static void registerWith() {
    AdapterRegistry.instance.register(InmobiAdapter());
  }

  /// Platform-view type of the native banner.
  static const viewType = 'dev.arovyx.plugin.unifiedads/inmobi/banner';

  InmobiHostApi? _hostApi;
  final BinaryMessenger? _messenger;
  RewardItem _defaultReward = const RewardItem(amount: 1, type: 'reward');

  InmobiHostApi get _host =>
      _hostApi ??= InmobiHostApi(binaryMessenger: _messenger);

  @override
  AdNetwork get network => AdNetwork.inmobi;

  @override
  Set<AdFormat> get supportedFormats => const {
    AdFormat.banner,
    AdFormat.interstitial,
    AdFormat.rewarded,
  };

  @override
  TestModeSupport get testModeSupport => TestModeSupport.none;
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
      InmobiEventsApi.setUp(this, binaryMessenger: _messenger);

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

  /// Receives native events (Pigeon `InmobiEventsApi`). Not for app use.
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
