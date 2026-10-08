# Unity Ads setup (`unified_ads_unity`)

> **Getting the IDs:** how to create the account, app and every ID for this network is in
> [docs/getting_ids.md](../getting_ids.md#unity-ads).

| Platform | SDK (pinned) | Minimum |
|---|---|---|
| Android | `com.unity3d.ads:unity-ads:4.21.0` | API 19 (project: 24); compileSdk 33+ |
| iOS | `UnityAds` 4.21.0 (**CocoaPods only**: Unity publishes no SPM package) | iOS 13 |

Only the **4.19+ instance APIs** (`InterstitialAd`, `RewardedAd`, `BannerAd`) are used. The static API
(`UnityAds.load/show`, `BannerView`) is deprecated and removed in 5.0.

> **Placements are bidding-only:** Unity phased out waterfall placements (migration deadline 11 Aug 2026); new
> placements are created with setup type *Bidding*. Every project includes six default bidding placements.

## Config

```dart
AdNetwork.unity: NetworkConfig(
  appId: PlatformValue.select(android: '<Android Game ID>', ios: '<iOS Game ID>'),
  bannerAdUnitId: 'Banner_Android',            // placement IDs from the Unity dashboard
  interstitialAdUnitId: 'Interstitial_Android',
  rewardedAdUnitId: 'Rewarded_Android',
  extras: {'rewardAmount': 10, 'rewardType': 'coins'},  // Unity rewards carry no amount
),
```

- **Do not enable together with LevelPlay** (see `docs/setup/ironsource.md`). unified_ads skips Unity in that case.
- **Test mode** (`TestModeSupport.flag`): `withTestMode(true)` at init. A real Game ID from the Unity dashboard is still required.
- **Rewards:** Unity's reward callback has no amount or type. The adapter reports `extras['rewardAmount']` /
  `extras['rewardType']` (default `1` / `'reward'`).
- **Banner sizes:** 320×50, 300×250 (MREC) and 728×90. Adaptive sizing is not documented for the new API, so adaptive
  requests fall back to 320×50.
- **Impressions:** the full-screen "started" callback is reported as both `shown` and `impression`.

## Privacy

`consentGiven` sets `UnityAds.userConsent`, `ccpaOptOut` sets `userOptOut`, and `coppa` sets `nonBehavioral`. These are set
before init, as Unity requires.

## Platform notes

- **Android:** Maven Central. R8 rules are bundled (4.20+ is required for AGP 9). AD_ID is declared by the SDK.
  Use only the lite protobuf variant in the app.
- **iOS:** add `SKAdNetworkItems` from https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json and
  `NSUserTrackingUsageDescription`.

## Error mapping (`UnityAdsError.code`)

| Code | `AdErrorCode` |
|---|---|
| 52100 | `noFill` |
| 52101 | `notInitialized` |
| 52102, 52104 (placement not found / unsupported) | `invalidConfig` |
| 2 | `timeout` |
| 52005, 52105 ⚠ | `networkError` |
| show: 52200 ⚠ expired / 52201 ⚠ already showing | `notReady` / `alreadyShowing` |

⚠ These codes come from AppLovin's open-source Unity adapter, not from an official Unity table.

## API names used

- ✅ **Android: compiler-verified** against 4.21.0:
  - `InitializationConfiguration.Builder(gameId).withTestMode(...)` + `InitializationListener`
  - `InterstitialAd.load` / `RewardedAd.load` with `LoadListener`
  - `InterstitialShowListener` / `RewardedShowListener`
  - `BannerAd.load` + `BannerConfiguration` + `BannerShowListener`
  - The privacy **properties** `UnityAds.userConsent` / `userOptOut` / `nonBehavioral`, which are Kotlin properties, not setter
    functions as some docs show.
- ⚠ **iOS: not yet compiled.** Unity's docs conflict (e.g. `showDidFail` vs `showDidFailed`). The code follows the guides,
  to be verified in Phase 6 CI.
