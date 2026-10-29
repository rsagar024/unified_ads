# unified_ads_inmobi 📱

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_inmobi.svg)](https://pub.dev/packages/unified_ads_inmobi)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

InMobi adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial and rewarded** ads.
Adding this package links **only** the InMobi SDK into your app.

## ✨ Features

- 🎯 **No hardcoding:** the Account ID and numeric placement IDs live in your `AdConfig` (or `ads_config.json`), and
  are validated at init.
- 🧩 **Three formats, one API:** `BannerAd` + `UnifiedBannerWidget`, `InterstitialAd` and `RewardedAd`. Every ad
  reports the network that served it (`servedBy`).
- 🌊 **Waterfall fallback:** combine InMobi with other networks; if one has no fill, the next is tried.
- ⏱️ **Pacing and frequency caps:** set a cooldown between interstitials, show one every N user actions, skip the
  first seconds after launch, and cap shows per time window.
- 👑 **Pro users and ad-free mode:** `UnifiedAds.setAdFree(true)` collapses banners and blocks interstitials.
- 🔐 **Privacy aware:** reads IAB TCF / GPP strings from your CMP, plus explicit GDPR / CCPA / COPPA signals.
- 🪶 **Opt-in linking:** only the InMobi SDK is added to your APK / IPA.

| | Android | iOS |
|---|---|---|
| SDK | `com.inmobi.monetization:inmobi-ads-kotlin:11.5.1` (the Java artifact `inmobi-ads` is abandoned) | `InMobiSDK` 11.5.0 |
| Minimum | API 21 (package: 24); **Kotlin 2.x, AGP ≥ 8.9.3** | iOS 12, Xcode 15+ (package: 13) |
| Distribution | Gradle (Maven Central) | Swift Package Manager (`InMobi/InMobiSDK-Swift-Package`, product `InMobiSDK`) |

## 🚀 Getting Started

### 1. Add the dependency

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_inmobi: ^1.1.0
```

### 2. Platform setup

#### Android

Every dependency (OkHttp, Picasso, media3, coroutines, …) comes through the POM; the AAR ships its ProGuard rules and
merges its activities and permissions. Keep `android:hardwareAccelerated="true"` on `<application>`.

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
<key>SKAdNetworkItems</key>
<array>
  <dict><key>SKAdNetworkIdentifier</key><string>wzmmz9fp6w.skadnetwork</string></dict>
  <!-- + the full list from InMobi's iOS guidelines -->
</array>
```

- InMobi **requires** `-ObjC`, `libz`, `libsqlite3.0` and `WebKit`: the adapter's `Package.swift` links all four, and
  you should also add `-ObjC` to Runner → Build Settings → Other Linker Flags (the setting InMobi documents).
- InMobi recommends `NSAllowsArbitraryLoads = YES`; flag it for App Store review.

## 📖 Usage

### 1. Initialize at app launch

```dart
import 'package:flutter/material.dart';
import 'package:unified_ads/unified_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await UnifiedAds.setAdFree(await isProUser());    // optional, see step 5
  await UnifiedAds.requestTrackingAuthorization();  // iOS prompt; Android: notApplicable
  await UnifiedAds.init(AdConfig(
    networks: {
      AdNetwork.inmobi: NetworkConfig(
        appId: '<InMobi account ID>',
        bannerAdUnitId: '1234567890',         // placement IDs are NUMERIC (validated at init)
        interstitialAdUnitId: '1234567890',
        rewardedAdUnitId: '1234567890',       // a Rewarded Video placement
      ),
    },
    pacing: {
      AdFormat.interstitial: AdPacing(
        initialDelay: Duration(seconds: 30),
        minInterval: Duration(seconds: 15),
        showEveryActions: 3,
      ),
    },
  ));

  runApp(const MyApp());
}
```

### 2. Display a banner ad

```dart
final banner = BannerAd(size: BannerSize.standard);   // 320×50, MREC 300×250 or 728×90
// build():   UnifiedBannerWidget(ad: banner, anchored: true)
// dispose(): banner.dispose();
```

### 3. Show paced interstitial ads

```dart
final interstitial = InterstitialAd(onClosed: (ad) => goToNextScreen());
await interstitial.load();

await UnifiedAds.recordAction();                 // after each user action
if (await interstitial.canShow()) {
  await interstitial.show();
} else {
  goToNextScreen();                              // paced, capped or ad-free: skip
}
```

### 4. Show rewarded video ads

```dart
final rewarded = RewardedAd(
  onEarnedReward: (ad, reward) => grant(reward.amount, reward.type),  // from the dashboard reward key/value
);
if ((await rewarded.load()).isSuccess) await rewarded.show();
```

### 5. Pro users / ad-free mode

```dart
await UnifiedAds.setAdFree(true);                      // banners + interstitials off
await UnifiedAds.setAdFree(true, blockRewarded: true); // rewarded off too
```

Blocked calls return `AdErrorCode.adsBlocked` without contacting InMobi.

## 🔑 Getting the IDs

You need: Account ID + numeric placement ID per format.

1. **Account:** InMobi publisher dashboard → **Create Account** → verify email. Add an app and a payment method to reach
   **Pending Approval** (about 24 working hours).
2. **Account ID:** top-left corner, under your account name.
3. **App:** **Inventory → Inventory Settings → Add Inventory** → Mobile App (store URL) or Unpublished App.
4. **Placements:** expand the app → **+ Add a placement** → **Banner** / **Interstitial** / **Rewarded Video** (with a
   reward key/value, e.g. `Coins` = `1000`). The long numeric **Placement ID** is under the name.
5. **Testing:** no code-level test flag. Turn test mode on **per placement** (Global or Device) and register devices
   under **Integration → Integration Testing**. With `testMode: true` the adapter logs at DEBUG so your advertising ID is
   printed. **Turn test mode off before release.**

## ⚙️ Details

### Notes

- **Test mode** (`TestModeSupport.none`): no code-level test flag. Enable test mode per placement in the InMobi
  dashboard ("Global ON", or "Selective ON" with your device ID). With `testMode` on, the adapter switches InMobi logging
  to DEBUG so the device ID is printed; unified_ads logs a warning at init.
- **Rewarded:** the reward is the first entry of InMobi's rewards map (`name → amount`), as configured on the dashboard.
- **Banner sizes:** no adaptive size. MREC is 300×250, leaderboard 728×90, everything else 320×50.
- **Activity:** InMobi needs an Activity to show interstitials, so full-screen ads load only while one is attached
  (otherwise `noActivity`).

### Privacy

IAB TCF / GPP strings from a CMP (e.g. UMP) are read automatically (SDK 10.7.5+). Explicitly: `consentGiven` /
`gdprApplies` → InMobi's GDPR consent object, `ccpaOptOut` → `InMobiPrivacyCompliance.setDoNotSell`, `coppa` →
`InMobiSdk.setIsAgeRestricted`.

### Error mapping (`InMobiAdRequestStatus.StatusCode` / `IMStatusCode`)

| Status | `AdErrorCode` |
|---|---|
| NO_FILL, AD_NO_LONGER_AVAILABLE | `noFill` |
| NETWORK_UNREACHABLE, SERVER_ERROR | `networkError` |
| REQUEST_TIMED_OUT | `timeout` |
| REQUEST_INVALID, CONFIGURATION_ERROR, MONETIZATION_DISABLED, MISSING_REQUIRED_DEPENDENCIES | `invalidConfig` |
| AD_ACTIVE | `alreadyShowing` |
| other | `internal` |

## 🛠️ Verification & Tests

```sh
flutter test                        # adapter unit tests (mocked host API)
cd example && flutter run           # the shared example app: enable InMobi in Settings
```

Android: the SDK initializes and requests round-trip on a device; InMobi's sample placements return NO_FILL for this
package, so serving needs your own placements (dashboard test mode). iOS builds in CI and hasn't run on a physical device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## 📄 License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
