# Unity Ads setup (`unified_ads_unity`)

> **Getting the IDs:** how to create the account, app and every ID for this network is in
> [doc/getting_ids.md](../getting_ids.md#unity-ads).

| Platform | SDK (pinned) | Minimum |
|---|---|---|
| Android | `com.unity3d.ads:unity-ads:4.21.0` | API 19 (project: 24); compileSdk 33+ |
| iOS | `UnityAds` 4.21.0 (Swift Package Manager: official `Unity-Technologies/Unity-Ads-Swift-Package`, product `UnityAds`) | iOS 13, **Xcode 26.0.1+** (since 4.18.0) |

Only the **4.19+ instance APIs** (`InterstitialAd`, `RewardedAd`, `BannerAd`) are used. The static API
(`UnityAds.load/show`, `BannerView`) is deprecated and scheduled for removal in 5.0.0 (not released as of 2026-10-28).

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

- **Do not enable together with LevelPlay** (see `doc/setup/ironsource.md`). unified_ads skips Unity in that case.
- **Test mode** (`TestModeSupport.flag`): `withTestMode(true)` at init. A real Game ID from the Unity dashboard is still required.
- **Rewards:** Unity's reward callback has no amount or type. The adapter reports `extras['rewardAmount']` /
  `extras['rewardType']` (default `1` / `'reward'`).
- **Banner sizes:** 320×50, 300×250 (MREC) and 728×90. The 4.21.0 binaries have only fixed sizes (Android
  `BannerSize.standard / iabStandard / leaderboard` or `BannerSize(w, h)`; iOS a `CGSize`), so adaptive requests fall
  back to 320×50. (Unity's deprecated-APIs page mentions adaptive sizes, but no factory exists in 4.21.0.)
- **Expiry:** the adapter sets `onAdExpired` on every loaded interstitial / rewarded ad, as Unity's guides require. An
  expired ad is dropped, so `show()` reports `notReady` and the core cache loads a fresh one.
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
| 52102, 52104 ("invalid configuration" in Unity's deprecated-APIs table) | `invalidConfig` |
| 2 | `timeout` |
| 52005, 52105 ⚠ | `networkError` |
| show: 52200 ⚠ expired / 52201 ⚠ already showing | `notReady` / `alreadyShowing` |

52100, 52101, 52102/52104 and 2 are in Unity's 4.21.0 deprecated-APIs table. ⚠ 52005, 52105, 52200 and 52201 come from
AppLovin's open-source Unity adapter, not from an official Unity table.

## API names used

- ✅ **Android: compiler-verified** against 4.21.0:
  - `InitializationConfiguration.Builder(gameId).withTestMode(...)` + `InitializationListener`
  - `InterstitialAd.load` / `RewardedAd.load` with `LoadListener`
  - `InterstitialShowListener` / `RewardedShowListener`
  - `BannerAd.load` + `BannerConfiguration` + `BannerShowListener`
  - `InterstitialAd.onAdExpired` / `RewardedAd.onAdExpired` (`AdExpiredListener`)
  - The privacy **properties** `UnityAds.userConsent` / `userOptOut` / `nonBehavioral`, which are Kotlin properties, not setter
    functions as some docs show.
- ✅ **iOS: checked against the 4.21.0 `UnityAds.swiftinterface`** (2026-10-28; not yet compiled in CI):
  `UADSInitializationConfigurationBuilder(gameId:)`, `UnityAds.initialize(_:completion:)`, `UADSInterstitialAd` /
  `UADSRewardedAd.load(_:completion:)`, `show(_:delegate:)`, the delegates' `showDidStart` / `showDidClick` /
  `showDidComplete(_:with:)` / **`showDidFail(_:error:)`** (Unity's Swift API page says `showDidFailed`, which doesn't
  exist) / `showDidReceiveReward`, `UnityAd.onAdExpired`, `UADSBannerAd.load` + `UADSBannerLoadConfigurationBuilder`
  (fixed `CGSize`), and `UnityAds.setUserConsent` / `setUserOptOut` / `setNonBehavioral`.
