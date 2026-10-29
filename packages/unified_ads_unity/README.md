# unified_ads_unity

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_unity.svg)](https://pub.dev/packages/unified_ads_unity)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

Unity Ads adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial and rewarded** ads.
Adding this package links **only** the Unity Ads SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.unity3d.ads:unity-ads:4.21.0` | `UnityAds` 4.21.0 |
| Minimum | API 19 (package: 24), compileSdk 33+ | iOS 13, Xcode 26.0.1+ |
| Distribution | Gradle (Maven Central) | Swift Package Manager (`Unity-Technologies/Unity-Ads-Swift-Package`, product `UnityAds`) |

Only the **4.19+ instance APIs** (`InterstitialAd`, `RewardedAd`, `BannerAd`) are used; the static API is deprecated and
scheduled for removal in 5.0.0 (not released yet). The iOS names were checked against the 4.21.0 `.swiftinterface`.

> **Don't use this together with `unified_ads_ironsource`.** The Unity SDK initializes once per process, so unified_ads
> skips Unity (`configConflict`) when LevelPlay is also enabled. With LevelPlay, get Unity demand through LevelPlay bidding.

## Install and use

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_unity: ^1.1.0
```

```dart
await UnifiedAds.init(AdConfig(
  testMode: true,
  networks: {
    AdNetwork.unity: NetworkConfig(
      appId: PlatformValue.select(android: '<Android Game ID>', ios: '<iOS Game ID>'),
      bannerAdUnitId: PlatformValue.select(android: 'Banner_Android', ios: 'Banner_iOS'),
      interstitialAdUnitId: PlatformValue.select(android: 'Interstitial_Android', ios: 'Interstitial_iOS'),
      rewardedAdUnitId: PlatformValue.select(android: 'Rewarded_Android', ios: 'Rewarded_iOS'),
      extras: {'rewardAmount': 10, 'rewardType': 'coins'},  // Unity rewards carry no amount
    ),
  },
));
```

## Getting the IDs

You need: Game ID per platform + placement ID per format.

> Use Unity Ads **directly** only if you don't use LevelPlay. With LevelPlay, enable Unity Ads as a bidder inside LevelPlay.

1. **Project:** [cloud.unity.com](https://cloud.unity.com) → **Projects → Create project** (the COPPA designation can't
   be changed later) → open **Monetization** and enable Unity Ads → add your store IDs in project **Settings**.
2. **Game IDs:** **project Settings → Game IDs**: one for Android, one for iOS.
3. **Placements:** every project has six default bidding placements (usually `Banner_Android`, `Interstitial_Android`,
   `Rewarded_Android` and the `_iOS` versions). Since 11 Aug 2026 new placements are **bidding only**.
4. **Testing:** `testMode: true`, or **Monetization → Settings → Test devices → Override client test mode → Force test
   mode ON for all devices** (register single devices with **Create test device**).

## Notes

- **Placements are bidding-only** since 11 Aug 2026; every project includes six default bidding placements.
- **Test mode** (`TestModeSupport.flag`): `withTestMode(true)` at init. A real Game ID is still required.
- **Rewards:** Unity's reward callback has no amount or type; the adapter reports `extras['rewardAmount']` /
  `extras['rewardType']` (default `1` / `'reward'`).
- **Banner sizes:** 320×50, 300×250 (MREC) and 728×90. 4.21.0 has no adaptive banner size, so adaptive requests fall
  back to 320×50.
- **Expiry:** Unity can expire a loaded ad (`onAdExpired`). The adapter drops it, so `show()` reports `notReady` and the
  core cache loads a fresh one.
- **Impressions:** the full-screen "started" callback is reported as both `shown` and `impression`.

## Platform setup

- **Android:** nothing to add to the manifest (Game ID is passed in code). R8 rules are bundled (4.20+ is required for
  AGP 9); AD_ID is declared by the SDK. Use only the lite protobuf variant in the app.
- **iOS:** `NSUserTrackingUsageDescription` and `SKAdNetworkItems` (own ID `4dzt52r2t5.skadnetwork`; full list at
  https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json).

## Privacy

`consentGiven` → `UnityAds.userConsent`, `ccpaOptOut` → `userOptOut`, `coppa` → `nonBehavioral`, all set before init.

## Error mapping (`UnityAdsError.code`)

| Code | `AdErrorCode` |
|---|---|
| 52100 | `noFill` |
| 52101 | `notInitialized` |
| 52102, 52104 (placement not found / unsupported) | `invalidConfig` |
| 2 | `timeout` |
| 52005, 52105 ⚠ | `networkError` |
| show: 52200 ⚠ expired / 52201 ⚠ already showing | `notReady` / `alreadyShowing` |

⚠ These codes come from AppLovin's open-source Unity adapter, not an official Unity table.

## Status

Android verified on a physical device with Unity's sample Game ID: banner, rewarded load, interstitial load + show. iOS
builds in CI and hasn't run on a physical device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
