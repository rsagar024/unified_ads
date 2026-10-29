# Facebook Audience Network setup (`unified_ads_facebook`)

> **Getting the IDs:** how to create the account, property and placement IDs is in
> [doc/getting_ids.md](../getting_ids.md#facebook-audience-network).

Facebook Audience Network (FAN) has been branded **Meta Audience Network** since 2022. It's the same product, and the SDK
artifacts still carry the Facebook name. In unified_ads it is `AdNetwork.facebook` (JSON id `"facebook"`).

| | Android | iOS |
|---|---|---|
| SDK | `com.facebook.android:audience-network-sdk:6.22.0` (latest on Maven) | `FBAudienceNetwork` 6.22.1 (Swift Package Manager: `github.com/facebook/FBAudienceNetwork`; rewarded / interstitial fixes) |
| Minimum OS | minSdk 24 (plugin-wide) | **iOS 15.0**: higher than the other adapters (iOS 13) |
| Formats | banner, interstitial, rewarded | banner, interstitial, rewarded |

## ⚠ Bidding-only: what to expect

Audience Network removed waterfall placements in 2021, so it is **bidding-only**. This adapter loads ads directly, which:

- **serves test ads**: with the test placement form `IMG_16_9_APP_INSTALL#<placement id>`, or for devices in
  `testDeviceIds`;
- **is not expected to fill in production**. Real ad requests to Audience Network go through a bidding auction. For revenue,
  add Audience Network as a bidder in AdMob, AppLovin MAX or LevelPlay (their Facebook/Meta mediation adapters). Those ads
  are then served by `admob` / `applovin` / `ironsource`.

**Bidding through the other adapters is built in (opt-in):** add the vendor's Meta adapter to your app and
`unified_ads_admob` / `unified_ads_applovin` / `unified_ads_ironsource` detect it and forward privacy. See the
"Meta (Facebook) bidding" section of [admob.md](admob.md#7-meta-facebook-bidding-opt-in),
[applovin.md](applovin.md#meta-facebook-bidding-opt-in) or [ironsource.md](ironsource.md#meta-facebook-bidding-opt-in).

Treat `unified_ads_facebook` as a way to integrate and test Audience Network formats and placements, and keep it last in the
waterfall (or out of production builds) unless Meta has enabled direct delivery for your property.

Decision history: A10 in `IMPLEMENTATION.md` (it started as a stub; the owner reversed this on 2026-10-07).

## Config

```dart
AdNetwork.facebook: NetworkConfig(
  // appId: not needed; Audience Network has no app ID in code.
  bannerAdUnitId: 'IMG_16_9_APP_INSTALL#<banner placement id>',
  interstitialAdUnitId: 'IMG_16_9_APP_INSTALL#<interstitial placement id>',
  rewardedAdUnitId: 'IMG_16_9_APP_INSTALL#<rewarded placement id>',
  testMode: true,
  testDeviceIds: ['<hashed device id>'],
  extras: {'rewardAmount': 1, 'rewardType': 'coins'},
),
```

- **Placement IDs** come from Monetization Manager. Each placement has a **display format**, which must match how you use it:
  a banner placement for `BannerAd`, an interstitial placement for interstitials, a rewarded video placement for rewarded ads.
  A mismatch fails with native 1011/1203 → `invalidConfig`.
- **Test mode** (`TestModeSupport.testDevices`): the SDK logs a hashed device ID on first request
  (logcat: `Test mode device hash: …`; Xcode console on iOS). Put it in `testDeviceIds` and set `testMode: true`. The
  adapter then calls `AdSettings.addTestDevices` / `FBAdSettings.addTestDevices`. The `IMG_16_9_APP_INSTALL#` prefix also
  forces a test creative without registering a device. On iOS (since 1.0.1), `testMode: true` with an empty
  `testDeviceIds` registers the current device (`FBAdSettings.testDeviceHash()`), because iOS serves no test ads, even
  on the simulator, to an unregistered device.
- **Rewards:** Audience Network reports "video completed" without an amount or type. `onEarnedReward` uses
  `extras['rewardAmount']` / `extras['rewardType']` (default `1` / `'reward'`). Server-side reward verification (Meta's
  `RewardData` S2S callback) is **not implemented yet**: `extras['userId']` reaches the native side but is not used.

## Android

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

If your app already has a network security config, add the `domain-config` above to it. The library does not ship one,
because an app can have only one and a library copy would silently override yours. No manifest meta-data or App ID is needed.
R8 rules ship inside the SDK AAR; the plugin adds a keep rule for its entry point.

## iOS

- **Deployment target 15.0** (FBAudienceNetwork 6.22). Set it on the Runner target in Xcode
  (`IPHONEOS_DEPLOYMENT_TARGET`).
- **Swift Package Manager only** (since 1.1.0): the adapter's `Package.swift` pins
  `https://github.com/facebook/FBAudienceNetwork` exact 6.22.1, product `FBAudienceNetwork`, which ships as a
  **dynamic** xcframework. Meta has said 6.22 is the last CocoaPods release, so later upgrades stay on SPM.
- **SKAdNetwork:** add Meta's IDs `v9wttpbfk9.skadnetwork` and `n38lu8286q.skadnetwork` to `SKAdNetworkItems` in Info.plist.
- **ATT:** request tracking authorization with `UnifiedAds.requestTrackingAuthorization()` before init. On iOS 15–16
  the adapter sets `FBAdSettings.setAdvertiserTrackingEnabled` from the ATT status (at consent time and again just
  before init), as Meta requires below iOS 17. On iOS 17+ SDK 6.15+ reads `ATTrackingManager` itself and the setter is
  deprecated, so it isn't called.
- `loadAd` has been deprecated since 6.11 ("use loadAdWithBidPayload") because of bidding. It is still the direct-load
  path and produces a compiler warning.

## Privacy

| unified_ads consent | Audience Network call |
|---|---|
| `ccpaOptOut: true` | `setDataProcessingOptions(["LDU"], 0, 0)` (Limited Data Use, geolocated) |
| `ccpaOptOut: false` | `setDataProcessingOptions([])` |
| `coppa` | `AdSettings.setMixedAudience` / `FBAdSettings.isMixedAudience` |
| ATT status (iOS 15–16 only) | `FBAdSettings.setAdvertiserTrackingEnabled` (iOS 17+: read by the SDK) |
| GDPR | Audience Network has no GDPR consent API; Meta relies on your CMP / TCF string |

## Errors

| Native code | Meaning | `AdErrorCode` |
|---|---|---|
| 1000 / 2000 | network / server error | `networkError` |
| 1001 | no fill (expected in production without bidding) | `noFill` |
| 1002 | load called too frequently | `frequencyCapped` |
| 1011 / 1203 | placement's display format doesn't match the request (seen on device with a non-rewarded placement used for rewarded) | `invalidConfig` |
| 2009 | timeout | `timeout` |
| 7003 | cleartext to 127.0.0.1 blocked (see Android above) | `invalidConfig` |
| 7005 / 7006 | missing dependency / API not supported | `invalidConfig` |
| 7002 | load called while showing | `alreadyShowing` |
| 7001 / 7004 (show) | show before load / wrong state | `notReady` |
| other | | `internal` (load) / `showFailed` (show) |

`AdError.nativeCode` always carries the original code.

## Device results (2026-10-07, CPH1931 / Android 10)

Using the `IMG_16_9_APP_INSTALL#` test placements published in the example app of the `facebook_audience_network` plugin
(listed in [getting_ids.md](../getting_ids.md#testing-without-your-own-ids)):

| init | banner | interstitial load | interstitial show | rewarded |
|---|---|---|---|---|
| ✅ | ✅ (+ impression) | ✅ | ✅ | ⛔ 1203 → `invalidConfig`: no public rewarded test placement; needs your own rewarded-format placement |

## API names used

- ✅ **Android: compiler-verified** against 6.22.0 (and checked with `javap`):
  - `AudienceNetworkAds.buildInitSettings(ctx).withInitListener { InitResult.isSuccess / message }.initialize()`
  - `AdSettings.addTestDevices`, `setDataProcessingOptions`, `setMixedAudience`
  - `InterstitialAd` / `RewardedVideoAd(ctx, placementId)`, `buildLoadAdConfig().withAdListener().build()`, `loadAd`,
    `isAdInvalidated`, `show()`, `destroy()`
  - `InterstitialAdListener`, `RewardedVideoAdListener` (`onRewardedVideoCompleted`, `onRewardedVideoClosed`)
  - `AdView(ctx, id, AdSize.BANNER_HEIGHT_50 | BANNER_HEIGHT_90 | RECTANGLE_HEIGHT_250)` + `AdListener`
  - `AdError` code constants
- ⚠ **iOS: not yet compiled** (Phase 6 CI). Names come from the 6.22.0 / 6.22.1 headers and Meta's Swift samples:
  - `FBAudienceNetworkAds.initialize(with:completionHandler:)`
  - `FBAdSettings.addTestDevices`, `setDataProcessingOptions(_:country:state:)`, `isMixedAudience`,
    `setAdvertiserTrackingEnabled(_:)` (deprecated from iOS 17; called only below it)
  - `FBInterstitialAd(placementID:)` / `FBRewardedVideoAd(placementID:)`, `load()`, `isAdValid`,
    `show(fromRootViewController:)`
  - `FBAdView(placementID:adSize:rootViewController:)`, `kFBAdSize*`
  - the delegate method Swift spellings

## Reference

The pub.dev plugin [`facebook_audience_network`](https://pub.dev/packages/facebook_audience_network) (v1.0.1, MIT, last
updated Dec 2021) was analysed as a reference. It is not used or copied: it floats `6.+` SDK versions and fails to build on
AGP 8, and on iOS it has no init, no test devices and no rewarded ads. This adapter fixes the gaps it has (banner
`destroy()` on dispose, init without an Activity, typed events) and follows Google's Meta mediation adapters for the 6.x
API shapes.
