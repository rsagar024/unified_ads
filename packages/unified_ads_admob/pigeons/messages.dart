// Pigeon schema for the AdMob adapter. Regenerate with:
//   dart run melos run pigeon
// (or, from this package: dart run pigeon --input pigeons/messages.dart)
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/dev/arovyx/plugin/unifiedads/admob/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.arovyx.plugin.unifiedads.admob'),
    swiftOut:
        'ios/unified_ads_admob/Sources/unified_ads_admob/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'unified_ads_admob',
  ),
)
/// Ad formats handled natively.
enum AdFormatMessage {
  banner,
  interstitial,
  rewarded,
  rewardedInterstitial,
  appOpen,
}

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

/// Debug geography for the UMP consent flow (testing only).
enum DebugGeographyMessage { eea, regulatedUsState, other }

class InitRequest {
  InitRequest({
    required this.appId,
    required this.testMode,
    required this.testDeviceIds,
  });

  /// App ID from the Dart config, compared against the manifest / Info.plist.
  String? appId;
  bool testMode;
  List<String> testDeviceIds;
}

/// Native facts reported back after initialization.
class InitInfo {
  InitInfo({required this.metaBiddingAdapter});

  /// Class name of the Meta (Facebook) bidding adapter the app added to its
  /// build, or null when none is present (see docs/setup).
  String? metaBiddingAdapter;
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

class GatherRequest {
  GatherRequest({
    required this.forceForm,
    required this.debugGeography,
    required this.testDeviceHashedIds,
  });

  bool forceForm;
  DebugGeographyMessage? debugGeography;
  List<String> testDeviceHashedIds;
}

/// UMP status plus the IAB values UMP stored on the device.
class ConsentInfo {
  ConsentInfo({
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    required this.gdprApplies,
    required this.tcString,
    required this.purposeConsents,
    required this.gppString,
  });

  bool canRequestAds;
  bool privacyOptionsRequired;

  /// `IABTCF_gdprApplies` (1 = applies, 0 = does not), if stored.
  int? gdprApplies;

  /// `IABTCF_TCString`.
  String? tcString;

  /// `IABTCF_PurposeConsents` ('0'/'1' per purpose).
  String? purposeConsents;

  /// `IABGPP_HDR_GppString`.
  String? gppString;
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

  /// An `AdErrorCode` name, for failure events.
  String? errorCode;
  String? errorMessage;
  String? nativeCode;
  double? rewardAmount;
  String? rewardType;
  double? width;
  double? height;
}

/// Dart → native. Failures are reported as platform errors whose `code` is an
/// `AdErrorCode` name and whose `details` is the SDK's own error code.
@HostApi()
abstract class AdmobHostApi {
  @async
  InitInfo initialize(InitRequest request);

  /// Loads a full-screen ad and returns its id.
  @async
  String load(AdFormatMessage format, String adUnitId);

  /// Completes when the ad is presented (or failed to present).
  @async
  void show(String adId);

  void destroy(String adId);

  void applyConsent(ConsentMessage consent);

  void dispose();

  @async
  ConsentInfo gatherConsent(GatherRequest request);

  @async
  void showPrivacyOptions();

  ConsentInfo consentInfo();
}

/// Native → Dart.
@FlutterApi()
abstract class AdmobEventsApi {
  void onAdEvent(AdEventMessage event);
}
