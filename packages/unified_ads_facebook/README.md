# unified_ads_facebook 📱

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_facebook.svg)](https://pub.dev/packages/unified_ads_facebook)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

Facebook Audience Network (branded Meta Audience Network) adapter for
[`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial and rewarded**.

## ✨ Features

- 🎯 **No hardcoding:** placement IDs live in your `AdConfig` (or `ads_config.json`). No App ID is needed in code.
- 🧩 **Three formats, one API:** `BannerAd` + `UnifiedBannerWidget`, `InterstitialAd` and `RewardedAd`. Every ad
  reports the network that served it (`servedBy`).
- 🌊 **Waterfall fallback:** keep Audience Network last in the `waterfall`; earlier networks are tried first.
- 🛡️ **Safe test mode:** test placements (`IMG_16_9_APP_INSTALL#…`) or registered test devices.
- ⏱️ **Pacing and frequency caps:** set a cooldown between interstitials, show one every N user actions, skip the
  first seconds after launch, and cap shows per time window.
- 👑 **Pro users and ad-free mode:** `UnifiedAds.setAdFree(true)` collapses banners and blocks interstitials.
- 🪶 **Opt-in linking:** apps that don't depend on this package never pull the Audience Network SDK.

| | Android | iOS |
|---|---|---|
| SDK | `com.facebook.android:audience-network-sdk:6.22.0` | `FBAudienceNetwork` 6.22.1 |
| Minimum | minSdk 24 (package) | **iOS 15.0** (higher than the other adapters) |
| Distribution | Gradle | Swift Package Manager (`github.com/facebook/FBAudienceNetwork`, dynamic xcframework) |

> **Read this first.** Audience Network has been **bidding-only since 2021**. A direct integration like this one serves
> **test ads** (test placements `IMG_16_9_APP_INSTALL#<placement id>` or registered test devices), but it is **not
> expected to fill in production**. For Facebook revenue, add Audience Network as a bidder in AdMob, AppLovin MAX or
> LevelPlay mediation (see [Meta bidding](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md#meta-facebook-bidding-through-mediation-opt-in)); those ads are then served by
> `admob` / `applovin` / `ironsource`. Keep this adapter last in the waterfall (or out of production builds) unless Meta
> has enabled direct delivery for your property.

## 🚀 Getting Started

### 1. Add the dependency

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_facebook: ^1.1.0
```

### 2. Platform setup

#### Android

**Cleartext for 127.0.0.1 is required.** The SDK plays cached media through a local proxy, which Android 9+ blocks
(`AdError 7003 CLEAR_TEXT_SUPPORT_NOT_ALLOWED`). Allow cleartext for that host **only**:

`android/app/src/main/res/xml/network_security_config.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">127.0.0.1</domain>
    </domain-config>
</network-security-config>
```

`AndroidManifest.xml`:
```xml
<application android:networkSecurityConfig="@xml/network_security_config" ...>
```

If your app already has a network security config, add the `domain-config` to it (the library doesn't ship one, because
an app can have only one). No manifest meta-data or App ID is needed; R8 rules ship inside the SDK AAR.

#### iOS

- **Deployment target 15.0** on the Runner target (`IPHONEOS_DEPLOYMENT_TARGET`). With 13.0 the build fails.
- **SKAdNetwork:** `v9wttpbfk9.skadnetwork` and `n38lu8286q.skadnetwork` (the whole list) in `SKAdNetworkItems`:

  ```xml
  <key>SKAdNetworkItems</key>
  <array>
    <dict><key>SKAdNetworkIdentifier</key><string>v9wttpbfk9.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>n38lu8286q.skadnetwork</string></dict>
  </array>
  ```

- **ATT:** add `NSUserTrackingUsageDescription` and call `UnifiedAds.requestTrackingAuthorization()` before init. On
  iOS 15–16 the adapter sets `FBAdSettings.setAdvertiserTrackingEnabled` from the ATT status, as Meta requires below
  iOS 17; on iOS 17+ SDK 6.15+ reads the status itself and the setter is deprecated, so it isn't called.
- `loadAd` has been deprecated since 6.11 ("use loadAdWithBidPayload") because of bidding. It's still the direct-load
  path and produces a compiler warning. Meta has said 6.22.x is the last CocoaPods series.
- **Pin compatibility:** this package pins `FBAudienceNetwork` exact 6.22.1, like AppLovin's (`6220100.0.0`) and
  LevelPlay's (`5.6.0`) Meta adapters. Google's Meta adapter (`6.22.000`) pins 6.22.0, so it can't share an iOS app with
  this version.

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
    waterfall: [AdNetwork.facebook],                 // keep it last next to other networks
    networks: {
      AdNetwork.facebook: NetworkConfig(
        // Audience Network needs no app ID in code.
        bannerAdUnitId: 'IMG_16_9_APP_INSTALL#YOUR_BANNER_PLACEMENT_ID',
        interstitialAdUnitId: 'IMG_16_9_APP_INSTALL#YOUR_INTERSTITIAL_PLACEMENT_ID',
        rewardedAdUnitId: 'IMG_16_9_APP_INSTALL#YOUR_REWARDED_PLACEMENT_ID',
        testMode: true,
        testDeviceIds: ['<hashed id printed by the SDK in logcat / Xcode console>'],
        extras: {'rewardAmount': 1, 'rewardType': 'coins'}, // reward reported to Dart
      ),
    },
    pacing: {
      AdFormat.interstitial: AdPacing(
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
final banner = BannerAd(size: BannerSize.standard);   // use a banner-format placement
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

Blocked calls return `AdErrorCode.adsBlocked` without contacting Audience Network.

## 🔑 Getting the IDs

You need: placement IDs only.

1. Sign in to [Monetization Manager](https://business.facebook.com/pub/start) → **Create Property** (Business Manager
   required) → add the Android and/or iOS platform.
2. **Create placement** per format (**Banner**, **Interstitial**, **Rewarded video**). The **Placement ID**
   (`<number>_<number>`) is in the Placements table. A placement only serves its own format (a mismatch fails with
   1011/1203 → `invalidConfig`).
3. **Testing:** prefix the placement ID with `IMG_16_9_APP_INSTALL#` for a test creative, or add the device hash the SDK
   logs (`Test mode device hash: …`) to `testDeviceIds` with `testMode: true`. Drop the prefix in release builds.
4. **Production:** Audience Network is **bidding-only**; direct requests aren't expected to fill. Add it as a bidder in
   AdMob, MAX or LevelPlay ([Meta bidding](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md#meta-facebook-bidding-through-mediation-opt-in)).

## ⚙️ Details

### Notes

- **Placements** must match their display format (banner placement for `BannerAd`, and so on). A mismatch fails with
  native 1011/1203 → `invalidConfig`.
- **Test mode** (`TestModeSupport.testDevices`): the SDK logs `Test mode device hash: …` on the first request. Put it in
  `testDeviceIds` with `testMode: true` (→ `AdSettings.addTestDevices`). The `IMG_16_9_APP_INSTALL#` prefix forces a test
  creative without registering a device. On iOS (since 1.0.1), `testMode: true` with empty `testDeviceIds` registers the
  current device, because iOS serves no test ads to an unregistered device, even on the simulator.
- **Rewards:** "video completed" has no amount; `onEarnedReward` uses `extras['rewardAmount']` / `extras['rewardType']`
  (default `1` / `'reward'`). Server-side reward verification is not implemented yet.

### Privacy

| unified_ads consent | Audience Network call |
|---|---|
| `ccpaOptOut: true` | `setDataProcessingOptions(["LDU"], 0, 0)` (Limited Data Use, geolocated) |
| `ccpaOptOut: false` | `setDataProcessingOptions([])` |
| `coppa` | `AdSettings.setMixedAudience` / `FBAdSettings.isMixedAudience` |
| ATT status (iOS 15–16) | `FBAdSettings.setAdvertiserTrackingEnabled` |
| GDPR | no GDPR API; Meta relies on your CMP / TCF string |

### Errors

| Native code | Meaning | `AdErrorCode` |
|---|---|---|
| 1000 / 2000 | network / server error | `networkError` |
| 1001 | no fill (expected in production without bidding) | `noFill` |
| 1002 | load called too frequently | `frequencyCapped` |
| 1011 / 1203 | placement format doesn't match the request | `invalidConfig` |
| 2009 | timeout | `timeout` |
| 7003 | cleartext to 127.0.0.1 blocked | `invalidConfig` |
| 7005 / 7006 | missing dependency / API not supported | `invalidConfig` |
| 7002 | load called while showing | `alreadyShowing` |
| 7001 / 7004 (show) | show before load / wrong state | `notReady` |
| other | | `internal` (load) / `showFailed` (show) |

### Credits

The SDK call shapes were cross-checked against the (abandoned, MIT-licensed)
[`facebook_audience_network`](https://pub.dev/packages/facebook_audience_network) plugin and Google's official Meta
mediation adapters. No code was copied. Every API name was verified against the 6.22.0 SDK binaries/headers.

## 🛠️ Verification & Tests

```sh
flutter test                        # adapter unit tests (mocked host API)
cd example && flutter run           # the shared example app: enable Facebook in Settings
```

Android verified on a physical device with public test placements: init, banner (+ impression), interstitial load + show.
Rewarded needs your own rewarded-format placement (no public one exists). iOS builds in CI and hasn't run on a physical
device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## 📄 License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
