// Pigeon schema for the Start.io adapter. Regenerate with:
//   dart run melos run pigeon
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/dev/arovyx/plugin/unifiedads/startapp/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.arovyx.plugin.unifiedads.startapp',
    ),
    swiftOut:
        'ios/unified_ads_startapp/Sources/unified_ads_startapp/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'unified_ads_startapp',
  ),
)
/// Ad formats handled natively.
enum AdFormatMessage { banner, interstitial, rewarded }

/// Event kinds sent from native to Dart.
enum AdEventKind {
  loaded,
  failedToLoad,
  failedToShow,
  shown,
  impression,
  clicked,
  closed,
  earnedReward,
  bannerSized,
}

class InitRequest {
  InitRequest({
    required this.appId,
    required this.testMode,
    required this.testDeviceIds,
    this.userId,
  });

  /// The network's app-level credential (see the adapter's setup doc).
  String appId;
  bool testMode;
  List<String> testDeviceIds;
  String? userId;
}

class ConsentMessage {
  ConsentMessage({
    required this.gdprApplies,
    required this.consentGiven,
    required this.ccpaOptOut,
    required this.coppa,
  });

  bool? gdprApplies;
  bool? consentGiven;
  bool? ccpaOptOut;
  bool coppa;
}

class AdEventMessage {
  AdEventMessage({
    required this.kind,
    required this.adId,
    required this.format,
    this.errorCode,
    this.errorMessage,
    this.nativeCode,
    this.rewardAmount,
    this.rewardType,
    this.width,
    this.height,
  });

  AdEventKind kind;
  String adId;
  AdFormatMessage format;

  /// An AdErrorCode name, for failure events.
  String? errorCode;
  String? errorMessage;
  String? nativeCode;
  double? rewardAmount;
  String? rewardType;
  double? width;
  double? height;
}

/// Dart to native. Failures are platform errors whose code is an AdErrorCode
/// name and whose details is the SDK error code.
@HostApi()
abstract class StartappHostApi {
  @async
  void initialize(InitRequest request);

  /// Loads a full-screen ad and returns its id.
  @async
  String load(AdFormatMessage format, String adUnitId);

  /// Completes when the ad is presented (or failed to present).
  @async
  void show(String adId);

  void destroy(String adId);

  void applyConsent(ConsentMessage consent);

  void dispose();
}

/// Native to Dart.
@FlutterApi()
abstract class StartappEventsApi {
  void onAdEvent(AdEventMessage event);
}
