# unified_ads_unity 📱

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_unity.svg)](https://pub.dev/packages/unified_ads_unity)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

Unity Ads adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial and rewarded** ads.
Adding this package links **only** the Unity Ads SDK into your app.

## ✨ Features

- 🎯 **No hardcoding:** Game IDs and placement IDs live in your `AdConfig` (or `ads_config.json`).
- 🧩 **Three formats, one API:** `BannerAd` + `UnifiedBannerWidget`, `InterstitialAd` and `RewardedAd`. Every ad
  reports the network that served it (`servedBy`).
- 🌊 **Waterfall fallback:** put Unity before or after other networks; if one has no fill, the next is tried.
- 🛡️ **Safe test mode:** `testMode: true` maps to Unity's `withTestMode(true)`.
- ⏱️ **Pacing and frequency caps:** set a cooldown between interstitials, show one every N user actions, skip the
  first seconds after launch, and cap shows per time window.
- 👑 **Pro users and ad-free mode:** `UnifiedAds.setAdFree(true)` collapses banners and blocks interstitials.
- 🆕 **Modern SDK APIs only:** uses the 4.19+ instance APIs (`InterstitialAd`, `RewardedAd`, `BannerAd`).
- 🪶 **Opt-in linking:** only the Unity Ads SDK is added to your APK / IPA.

| | Android | iOS |
|---|---|---|
| SDK | `com.unity3d.ads:unity-ads:4.21.0` | `UnityAds` 4.21.0 |
| Minimum | API 19 (package: 24), compileSdk 33+ | iOS 13, Xcode 26.0.1+ |
| Distribution | Gradle (Maven Central) | Swift Package Manager (`Unity-Technologies/Unity-Ads-Swift-Package`, product `UnityAds`) |

Only the **4.19+ instance APIs** are used; the static API is deprecated and scheduled for removal in 5.0.0 (not released
yet). The iOS names were checked against the 4.21.0 `.swiftinterface`.

> **Don't use this together with `unified_ads_ironsource`.** The Unity SDK initializes once per process, so unified_ads
> skips Unity (`configConflict`) when LevelPlay is also enabled. With LevelPlay, get Unity demand through LevelPlay bidding.

## 🚀 Getting Started

### 1. Add the dependency

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_unity: ^1.1.0
```

### 2. Platform setup

#### Android

Nothing to add to the manifest (the Game ID is passed in code). R8 rules are bundled (4.20+ is required for AGP 9);
AD_ID is declared by the SDK. Use only the lite protobuf variant in the app.

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
<key>SKAdNetworkItems</key>
<array>
  <dict><key>SKAdNetworkIdentifier</key><string>4dzt52r2t5.skadnetwork</string></dict>
  <!-- + every ID from https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json -->
</array>
```

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
      AdNetwork.unity: NetworkConfig(
        appId: PlatformValue.select(android: '<Android Game ID>', ios: '<iOS Game ID>'),
        bannerAdUnitId: PlatformValue.select(android: 'Banner_Android', ios: 'Banner_iOS'),
        interstitialAdUnitId: PlatformValue.select(android: 'Interstitial_Android', ios: 'Interstitial_iOS'),
        rewardedAdUnitId: PlatformValue.select(android: 'Rewarded_Android', ios: 'Rewarded_iOS'),
        extras: {'rewardAmount': 10, 'rewardType': 'coins'},  // Unity rewards carry no amount
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
final banner = BannerAd(size: BannerSize.standard);   // 320×50, 300×250 or 728×90
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
  onEarnedReward: (ad, reward) => grantCoins(reward.amount),   // from extras['rewardAmount']
);
if ((await rewarded.load()).isSuccess) await rewarded.show();
```

### 5. Pro users / ad-free mode

```dart
await UnifiedAds.setAdFree(true);                      // banners + interstitials off
await UnifiedAds.setAdFree(true, blockRewarded: true); // rewarded off too
```

Blocked calls return `AdErrorCode.adsBlocked` without contacting Unity.

## 🔑 Getting the IDs

You need: Game ID per platform + placement ID per format.

> Use Unity Ads **directly** only if you don't use LevelPlay. With LevelPlay, enable Unity Ads as a bidder inside LevelPlay.

1. **Project:** [cloud.unity.com](https://cloud.unity.com) → **Projects → Create project** (the COPPA designation can't
   be changed later) → open **Monetization** and enable Unity Ads → add your store IDs in project **Settings**.
2. **Game IDs:** **project Settings → Game IDs**: one for Android, one for iOS.
3. **Placements:** every project has six default bidding placements (usually `Banner_Android`, `Interstitial_Android`,
   `Rewarded_Android` and the `_iOS` versions). Since 11 Aug 2026 new placements are **bidding only**.
4. **Testing:** `testMode: true`, or **Monetization → Settings → Test devices → Override client test mode → Force test
   mode ON for all devices** (register single devices with **Create test device**).

## ⚙️ Details

### Notes

- **Placements are bidding-only** since 11 Aug 2026; every project includes six default bidding placements.
- **Test mode** (`TestModeSupport.flag`): `withTestMode(true)` at init. A real Game ID is still required.
- **Rewards:** Unity's reward callback has no amount or type; the adapter reports `extras['rewardAmount']` /
  `extras['rewardType']` (default `1` / `'reward'`).
- **Banner sizes:** 320×50, 300×250 (MREC) and 728×90. 4.21.0 has no adaptive banner size, so adaptive requests fall
  back to 320×50.
- **Expiry:** Unity can expire a loaded ad (`onAdExpired`). The adapter drops it, so `show()` reports `notReady` and the
  core cache loads a fresh one.
- **Impressions:** the full-screen "started" callback is reported as both `shown` and `impression`.

### Privacy

`consentGiven` → `UnityAds.userConsent`, `ccpaOptOut` → `userOptOut`, `coppa` → `nonBehavioral`, all set before init.

### Error mapping (`UnityAdsError.code`)

| Code | `AdErrorCode` |
|---|---|
| 52100 | `noFill` |
| 52101 | `notInitialized` |
| 52102, 52104 (placement not found / unsupported) | `invalidConfig` |
| 2 | `timeout` |
| 52005, 52105 ⚠ | `networkError` |
| show: 52200 ⚠ expired / 52201 ⚠ already showing | `notReady` / `alreadyShowing` |

⚠ These codes come from AppLovin's open-source Unity adapter, not an official Unity table.

## 🛠️ Verification & Tests

```sh
flutter test                        # adapter unit tests (mocked host API)
cd example && flutter run           # the shared example app: enable Unity in Settings
```

Android verified on a physical device with Unity's sample Game ID: banner, rewarded load, interstitial load + show. iOS
builds in CI and hasn't run on a physical device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## 📄 License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
