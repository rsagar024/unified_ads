# unified_ads_facebook

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_facebook.svg)](https://pub.dev/packages/unified_ads_facebook)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

Facebook Audience Network (branded Meta Audience Network) adapter for
[`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial and rewarded**.

| | Android | iOS |
|---|---|---|
| SDK | `com.facebook.android:audience-network-sdk:6.22.0` | `FBAudienceNetwork` 6.22.0 |
| Minimum | minSdk 24 (package) | **iOS 15.0** (higher than the other adapters) |
| Distribution | Gradle | Swift Package Manager (`github.com/facebook/FBAudienceNetwork`, dynamic xcframework) |

Apps that don't depend on this package never pull the Audience Network SDK.

> **Read this first.** Audience Network has been **bidding-only since 2021**. A direct integration like this one serves
> **test ads** (test placements `IMG_16_9_APP_INSTALL#<placement id>` or registered test devices), but it is **not
> expected to fill in production**. For Facebook revenue, add Audience Network as a bidder in AdMob, AppLovin MAX or
> LevelPlay mediation (see [Meta bidding](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md#meta-facebook-bidding-through-mediation-opt-in)); those ads are then served by
> `admob` / `applovin` / `ironsource`. Keep this adapter last in the waterfall (or out of production builds) unless Meta
> has enabled direct delivery for your property.

## Install and use

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_facebook: ^1.1.0
```

```dart
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_facebook/unified_ads_facebook.dart';

await UnifiedAds.init(AdConfig(
  waterfall: [AdNetwork.facebook],
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
));
```

## Getting the IDs

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

## Notes

- **Placements** must match their display format (banner placement for `BannerAd`, and so on). A mismatch fails with
  native 1011/1203 → `invalidConfig`.
- **Test mode** (`TestModeSupport.testDevices`): the SDK logs `Test mode device hash: …` on the first request. Put it in
  `testDeviceIds` with `testMode: true` (→ `AdSettings.addTestDevices`). The `IMG_16_9_APP_INSTALL#` prefix forces a test
  creative without registering a device. On iOS (since 1.0.1), `testMode: true` with empty `testDeviceIds` registers the
  current device, because iOS serves no test ads to an unregistered device, even on the simulator.
- **Rewards:** "video completed" has no amount; `onEarnedReward` uses `extras['rewardAmount']` / `extras['rewardType']`
  (default `1` / `'reward'`). Server-side reward verification is not implemented yet.

## Android setup

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

## iOS setup

- **Deployment target 15.0** on the Runner target (`IPHONEOS_DEPLOYMENT_TARGET`). With 13.0 the build fails.
- **SKAdNetwork:** `v9wttpbfk9.skadnetwork` and `n38lu8286q.skadnetwork` (the whole list) in `SKAdNetworkItems`.
- **ATT:** call `UnifiedAds.requestTrackingAuthorization()` before init. Since SDK 6.15 / iOS 17 the SDK reads the ATT
  status itself; the deprecated `setAdvertiserTrackingEnabled:` is not used.
- `loadAd` is marked deprecated in 6.22 ("use loadAdWithBidPayload") because of bidding. It's still the direct-load path
  and produces a compiler warning. Meta has said 6.22 is the last CocoaPods release.

## Privacy

| unified_ads consent | Audience Network call |
|---|---|
| `ccpaOptOut: true` | `setDataProcessingOptions(["LDU"], 0, 0)` (Limited Data Use, geolocated) |
| `ccpaOptOut: false` | `setDataProcessingOptions([])` |
| `coppa` | `AdSettings.setMixedAudience` / `FBAdSettings.mixedAudience` |
| GDPR | no GDPR API; Meta relies on your CMP / TCF string |

## Errors

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

## Status

Android verified on a physical device with public test placements: init, banner (+ impression), interstitial load + show.
Rewarded needs your own rewarded-format placement (no public one exists). iOS builds in CI and hasn't run on a physical
device yet.

## Credits

The SDK call shapes were cross-checked against the (abandoned, MIT-licensed)
[`facebook_audience_network`](https://pub.dev/packages/facebook_audience_network) plugin and Google's official Meta
mediation adapters. No code was copied. Every API name was verified against the 6.22.0 SDK binaries/headers.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
