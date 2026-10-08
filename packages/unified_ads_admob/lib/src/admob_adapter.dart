import 'package:flutter/services.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'messages.g.dart';

/// unified_ads adapter for Google AdMob (Google Mobile Ads SDK).
///
/// Registered automatically when `unified_ads_admob` is a dependency of the
/// app. The AdMob App ID must also be declared in `AndroidManifest.xml` and
/// `Info.plist` (see docs/setup/admob.md).
///
/// Formats: banner, interstitial, rewarded, rewarded interstitial and app
/// open. Android uses the GMA Next-Gen SDK, iOS the Google Mobile Ads SDK.
/// Test mode uses AdMob test devices (`NetworkConfig.testDeviceIds`);
/// emulators and simulators are always test devices, and Google's demo
/// ad-unit IDs always serve test ads.
///
/// Meta (Facebook) bidding is opt-in: add Google's Meta mediation adapter to
/// the app's build and this adapter detects it and forwards privacy settings
/// (see docs/setup/admob.md).
class AdmobAdapter extends BridgedAdNetworkAdapter implements AdmobEventsApi {
  /// Creates the adapter. `hostApi` and `binaryMessenger` are for tests.
  AdmobAdapter({this._hostApi, this._messenger});

  /// Registers the adapter; called by Flutter's plugin registrant.
  static void registerWith() {
    AdapterRegistry.instance.register(AdmobAdapter());
  }

  /// Platform-view type of the native banner.
  static const viewType = 'dev.arovyx.plugin.unifiedads/admob/banner';

  AdmobHostApi? _hostApi;
  final BinaryMessenger? _messenger;

  AdmobHostApi get _host =>
      _hostApi ??= AdmobHostApi(binaryMessenger: _messenger);

  @override
  AdNetwork get network => AdNetwork.admob;

  @override
  Set<AdFormat> get supportedFormats => const {
    AdFormat.banner,
    AdFormat.interstitial,
    AdFormat.rewarded,
    AdFormat.rewardedInterstitial,
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
      AdmobEventsApi.setUp(this, binaryMessenger: _messenger);

  @override
  Future<void> nativeInitialize(
    NetworkConfig config, {
    required bool testMode,
  }) async {
    final info = await _host.initialize(
      InitRequest(
        appId: config.appId,
        testMode: testMode,
        testDeviceIds: config.testDeviceIds,
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
        AdFormat.rewardedInterstitial => AdFormatMessage.rewardedInterstitial,
        AdFormat.appOpen => AdFormatMessage.appOpen,
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

  /// Receives native events (Pigeon `AdmobEventsApi`). Not for app use.
  @override
  void onAdEvent(AdEventMessage event) => emitNativeEvent(
    kind: event.kind.name,
    adId: event.adId,
    format: event.format.name,
    errorCode: event.errorCode,
    errorMessage: event.errorMessage,
    nativeCode: event.nativeCode,
    rewardAmount: event.rewardAmount,
    rewardType: event.rewardType,
    width: event.width,
    height: event.height,
  );
}
