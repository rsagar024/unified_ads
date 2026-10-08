import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads_admob/src/messages.g.dart';

/// In-memory replacement for the native side.
class FakeHost extends AdmobHostApi {
  InitRequest? initRequest;
  String? metaBiddingAdapter;
  PlatformException? initError;
  final List<(AdFormatMessage, String)> loads = [];
  PlatformException? loadError;
  int _counter = 0;
  final List<String> shown = [];
  PlatformException? showError;
  final List<String> destroyed = [];
  final List<ConsentMessage> consents = [];
  int disposeCalls = 0;
  GatherRequest? gatherRequest;
  PlatformException? gatherError;
  bool privacyShown = false;
  ConsentInfo info = ConsentInfo(
    canRequestAds: true,
    privacyOptionsRequired: false,
  );

  @override
  Future<InitInfo> initialize(InitRequest request) async {
    initRequest = request;
    if (initError != null) throw initError!;
    return InitInfo(metaBiddingAdapter: metaBiddingAdapter);
  }

  @override
  Future<String> load(AdFormatMessage format, String adUnitId) async {
    loads.add((format, adUnitId));
    if (loadError != null) throw loadError!;
    return 'admob-${++_counter}';
  }

  @override
  Future<void> show(String adId) async {
    if (showError != null) throw showError!;
    shown.add(adId);
  }

  @override
  Future<void> destroy(String adId) async => destroyed.add(adId);

  @override
  Future<void> applyConsent(ConsentMessage consent) async =>
      consents.add(consent);

  @override
  Future<void> dispose() async => disposeCalls++;

  @override
  Future<ConsentInfo> gatherConsent(GatherRequest request) async {
    gatherRequest = request;
    if (gatherError != null) throw gatherError!;
    return info;
  }

  @override
  Future<void> showPrivacyOptions() async => privacyShown = true;

  @override
  Future<ConsentInfo> consentInfo() async => info;
}

/// Delivers [event] to Dart exactly as the native side would.
Future<void> sendNativeEvent(AdEventMessage event) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    'dev.flutter.pigeon.unified_ads_admob.AdmobEventsApi.onAdEvent',
    AdmobEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[event]),
    (_) {},
  );
}
