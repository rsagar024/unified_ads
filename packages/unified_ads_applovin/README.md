# unified_ads_applovin 📱

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_applovin.svg)](https://pub.dev/packages/unified_ads_applovin)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

AppLovin MAX adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial, rewarded and
app open** ads. Adding this package links **only** the AppLovin MAX SDK into your app.

## ✨ Features

- 🎯 **No hardcoding:** the SDK key and MAX ad unit IDs live in your `AdConfig` (or `ads_config.json`). No manifest or
  plist key is needed.
- 🧩 **Four formats, one API:** `BannerAd` + `UnifiedBannerWidget` (including MREC and adaptive), `InterstitialAd`,
  `RewardedAd` and `AppOpenAd`. Every ad reports the network that served it (`servedBy`).
- 🌊 **Waterfall fallback:** if MAX has no fill, the next network in your `waterfall` is tried.
- 🛡️ **Safe test mode:** `testDeviceIds` are registered as MAX test devices when `testMode` is on.
- ⏱️ **Pacing and frequency caps:** set a cooldown between interstitials, show one every N user actions, skip the
  first seconds after launch, and cap shows per time window.
- 👑 **Pro users and ad-free mode:** `UnifiedAds.setAdFree(true)` collapses banners and blocks interstitials and app
  open ads.
- 🪶 **Opt-in linking:** only the MAX SDK is added to your APK / IPA.

| | Android | iOS |
|---|---|---|
| SDK | `com.applovin:applovin-sdk:13.6.4` | `AppLovinSDK` 13.6.4 |
| Minimum | **API 24** (13.6.3+) | iOS 13 (SDK: 12) |
| Distribution | Gradle (Maven Central) | Swift Package Manager (`AppLovin/AppLovin-MAX-Swift-Package`, product `AppLovinSDK`) |

## 🚀 Getting Started

### 1. Add the dependency

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_applovin: ^1.1.0
```

### 2. Platform setup

#### Android

Uses `google()` + `mavenCentral()`. ProGuard rules are bundled, and the permissions (INTERNET, ACCESS_NETWORK_STATE,
AD_ID) are merged from the SDK manifest. **Nothing to add to the manifest.**

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
<key>SKAdNetworkItems</key>
<array>
  <dict><key>SKAdNetworkIdentifier</key><string>ludvb6z3bs.skadnetwork</string></dict>
  <!-- + every ID from https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json -->
</array>
```

If MAX fails with undefined symbols or unrecognized selectors, add `-ObjC` to the Runner target's Other Linker Flags. The
framework ships its own privacy manifest.

## 📖 Usage

### 1. Initialize at app launch

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unified_ads/unified_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await UnifiedAds.setAdFree(await isProUser());    // optional, see step 5
  await UnifiedAds.requestTrackingAuthorization();  // iOS prompt; Android: notApplicable
  await UnifiedAds.init(AdConfig(
    testMode: kDebugMode,
    networks: {
      AdNetwork.applovin: NetworkConfig(
        appId: '<MAX SDK key>',                 // passed in code; no manifest/plist key needed
        bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…',
        appOpenAdUnitId: '…',                   // App open (MAX has no rewarded interstitial)
        testDeviceIds: ['<GAID / IDFA>'],       // used when test mode is on
      ),
    },
    pacing: {
      AdFormat.interstitial: AdPacing(
        initialDelay: Duration(seconds: 30),
        minInterval: Duration(seconds: 15),
        showEveryActions: 3,
      ),
      AdFormat.appOpen: AdPacing(minInterval: Duration(minutes: 5)),
    },
  ));

  runApp(const MyApp());
}
```

### 2. Display a banner ad

```dart
final banner = BannerAd(size: const BannerSize.adaptiveAnchored());   // or BannerSize.mediumRectangle (MREC)
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
  onEarnedReward: (ad, reward) => grantCoins(reward.amount, reward.type),
);
if ((await rewarded.load()).isSuccess) await rewarded.show();
```

`AppOpenAd` loads a `MaxAppOpenAd`; show it on app resume, paced with `pacing: {AdFormat.appOpen: …}`.

### 5. Pro users / ad-free mode

```dart
await UnifiedAds.setAdFree(true);                      // banners, interstitials, app open off
await UnifiedAds.setAdFree(true, blockRewarded: true); // rewarded off too
```

Blocked calls return `AdErrorCode.adsBlocked` without contacting MAX.

## 🔑 Getting the IDs

You need: SDK key + one MAX ad unit ID per format and platform.

1. **Account:** sign up at [dash.applovin.com/signup](https://dash.applovin.com/signup). Account approval may be
   required (use the same email as your store listing). Set payments and your website domain.
2. **SDK key:** **Account → General → Keys** → copy the **SDK Key** (`appId`).
3. **Ad units:** **MAX → Mediation → Manage → Ad Units → Create Your Ad Unit** → name, platform, format (**Banner**,
   **Interstitial**, **Rewarded**, or **MRec** for `BannerSize.mediumRectangle`) → find your app or **Manually Add Your
   Package Name**. The package name / bundle ID is **case-sensitive** and must match exactly. `AppOpenAd` needs an
   App Open unit (`appOpenAdUnitId`; ⚠ AppLovin's help page doesn't list App Open; ask your account manager if your
   dashboard doesn't offer it).
4. **Testing:** put your GAID / IDFA in `testDeviceIds` with `testMode: true`; the **Mediation Debugger** can force test
   ads. If every MAX load **times out**, the SDK key or package name is wrong (MAX reports no error for an invalid key).

## ⚙️ Details

### Notes

- **Test mode** (`TestModeSupport.testDevices`): `testDeviceIds` are registered as MAX test devices when `testMode` is on.
  MAX has no public demo ad units, so you need a dashboard app with real ad units. The Mediation Debugger helps validate.
- **Banner sizes:** standard = a fixed 320×50 `MaxAdFormat.BANNER`, MREC = `MaxAdFormat.MREC`, leaderboard =
  `MaxAdFormat.LEADER`; adaptive anchored / inline opt in through `MaxAdViewConfiguration` / `MAAdViewConfiguration`
  (`ANCHORED` / `INLINE`, MAX 13.2.0+). The resolved size comes from `MaxAd.size`.
- **Context-free APIs:** MAX 13.3.0 deprecated every API that takes a `Context`; the adapter uses only the new forms.
- **App open:** `AppOpenAd` loads a `MaxAppOpenAd`, which MAX presents from its own window. MAX has no rewarded
  interstitial; the waterfall skips MAX for `RewardedInterstitialAd`.
- **Impressions** come from MAX's revenue callback (`onAdRevenuePaid`, once per impression).
- **Invalid SDK key:** MAX still reports init success, then never calls the load callbacks. unified_ads' timeouts turn
  this into `AdErrorCode.timeout`. If every MAX load times out, check the SDK key and package name.
- **Rewarded ads are singletons per ad unit** in MAX; keep one rewarded ad per unit (the cache already does).

### Privacy

- `consentGiven` → `AppLovinPrivacySettings.setHasUserConsent`; `ccpaOptOut` → `setDoNotSell`. Both applied **before** init.
- Google UMP's TCF strings are picked up automatically (MAX 12.0+).
- **COPPA:** MAX removed COPPA support in 13.0. When `ConsentState.coppa` is true, unified_ads skips MAX
  (`configConflict`), and the adapter also refuses init.

### Error mapping (`MaxErrorCode`)

| Code | `AdErrorCode` |
|---|---|
| 204 NO_FILL | `noFill` |
| -1000 NETWORK_ERROR, -1009 NO_NETWORK | `networkError` |
| -1001 NETWORK_TIMEOUT | `timeout` |
| -5603 INVALID_AD_UNIT_ID | `invalidConfig` |
| show: -23 already showing / -24 not ready / -5602 (Android) or -25 (iOS invalid view controller) | `alreadyShowing` / `notReady` / `noActivity` |
| other | `internal` / `showFailed` |

### Meta (Facebook) bidding: opt-in

This package declares **no** Meta dependency. Add AppLovin's Meta adapter to **your app**; the adapter detects it at init
and forwards privacy (`ccpaOptOut` → Limited Data Use via `AdSettings.setDataProcessingOptions`, `coppa` → mixed
audience) before MAX initializes it.

```kotlin
// android/app/build.gradle.kts
dependencies {
    implementation("com.applovin.mediation:facebook-adapter:6.22.0.1") // brings Audience Network 6.22.0
}
```

iOS (15.0+): **File → Add Package Dependencies…** → `https://github.com/AppLovin/AppLovin-MAX-Swift-Package-Meta`, exact
`6220100.0.0` (pins `FBAudienceNetwork` 6.22.1), product `AppLovinMediationFacebookAdapter`, on the **Runner** target. Add Meta's SKAdNetwork IDs and the
Android `127.0.0.1` cleartext config. Select Meta as a bidder on your MAX ad units and list AppLovin as the mediation
partner in Monetization Manager. On iOS 15–16 the adapter also sets `FBAdSettings.setAdvertiserTrackingEnabled` from the ATT status (Meta requires it below iOS 17).

## 🛠️ Verification & Tests

```sh
flutter test                        # adapter unit tests (mocked host API)
cd example && flutter run           # the shared example app: enable AppLovin in Settings
```

Android compiles and runs on a device; there are no public MAX credentials, so serving needs your own SDK key and ad
units. iOS builds in CI and hasn't run on a physical device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## 📄 License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
