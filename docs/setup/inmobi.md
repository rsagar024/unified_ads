# InMobi setup (`unified_ads_inmobi`)

> **Getting the IDs:** how to create the account, app and every ID for this network is in
> [docs/getting_ids.md](../getting_ids.md#inmobi).

| Platform | SDK (pinned) | Minimum |
|---|---|---|
| Android | `com.inmobi.monetization:inmobi-ads-kotlin:11.5.0` (the old Java artifact `inmobi-ads` is abandoned) | API 21 (project: 24); **Kotlin 2.x, AGP ≥ 8.9.3** |
| iOS | `InMobiSDK` 11.5.0 (**CocoaPods only**; no official SPM package) | iOS 12 (project: 13) |

## Config

```dart
AdNetwork.inmobi: NetworkConfig(
  appId: '<InMobi account ID>',
  bannerAdUnitId: '1234567890',         // placement IDs are NUMERIC (validated at init)
  interstitialAdUnitId: '1234567890',
  rewardedAdUnitId: '1234567890',       // a rewarded placement; same InMobiInterstitial class
),
```

- **Test mode** (`TestModeSupport.none`): InMobi has no code-level test flag. Enable test mode per placement in the
  InMobi dashboard ("Global ON", or "Selective ON" with your device ID). With `testMode` on, the adapter switches InMobi
  logging to DEBUG so the device ID is printed. unified_ads logs a warning at init for this network.
- **Rewarded:** the reward is the first entry of InMobi's rewards map (`name → amount`), as configured on the dashboard.
- **Banner sizes:** InMobi has no adaptive size. MREC is 300×250, leaderboard 728×90, everything else 320×50. On Android the banner
  is sized through `layoutParams` before `load()`, because `setBannerSize` is deprecated.
- **Activity:** InMobi needs an Activity context to show interstitials, so full-screen ads load only while an Activity
  is attached (otherwise `noActivity`).

## Privacy

- A CMP's IAB TCF and GPP strings (e.g. from UMP) are read automatically (SDK 10.7.5+).
- Explicit signals: `consentGiven`/`gdprApplies` are sent as InMobi's GDPR consent object, `ccpaOptOut` sets
  `InMobiPrivacyCompliance.setDoNotSell`, and `coppa` sets `InMobiSdk.setIsAgeRestricted`.

## Platform notes

- **Android:** every dependency (OkHttp, Picasso, media3, coroutines, …) comes transitively through the POM. The AAR ships its ProGuard rules
  and merges its activities and permissions. Keep `android:hardwareAccelerated="true"`.
- **iOS:**
  - InMobi recommends `NSAllowsArbitraryLoads = YES` under `NSAppTransportSecurity`. **Flag this for App Store review.**
  - Add `SKAdNetworkItems` from InMobi's list (linked from InMobi's iOS overview page) and `NSUserTrackingUsageDescription`.
  - It's a dynamic xcframework; the pod sets `-ObjC`.

## Error mapping (`InMobiAdRequestStatus.StatusCode` / `IMStatusCode`)

| Status | `AdErrorCode` |
|---|---|
| NO_FILL, AD_NO_LONGER_AVAILABLE | `noFill` |
| NETWORK_UNREACHABLE, SERVER_ERROR | `networkError` |
| REQUEST_TIMED_OUT | `timeout` |
| REQUEST_INVALID, CONFIGURATION_ERROR, MONETIZATION_DISABLED, MISSING_REQUIRED_DEPENDENCIES (iOS: incorrect placement ID) | `invalidConfig` |
| AD_ACTIVE | `alreadyShowing` |
| other (incl. FEATURE_DISABLED, DEVICE_AUDIO_LEVEL_LOW) | `internal` |

## API names used

- ✅ **Android: compiler-verified** against 11.5.0:
  - `InMobiSdk.init(ctx, account, json, SdkInitializationListener)` with `java.lang.Error?`
  - `InMobiInterstitial(activity, Long, InterstitialAdEventListener)`
  - `InMobiBanner` + `BannerAdEventListener`
  - `InMobiPrivacyCompliance`
- ⚠ **iOS: not yet compiled.**
  - Names come from the 11.5.0 `.swiftinterface`: `IMSdk`, `IMInterstitial(placementId:delegate:)`, `IMBanner(frame:placementId:)`.
  - The `IMStatusCode` raw values are inferred from enum order.
