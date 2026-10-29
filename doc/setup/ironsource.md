# ironSource / Unity LevelPlay setup (`unified_ads_ironsource`)

> **Getting the IDs:** how to create the account, app and every ID for this network is in
> [doc/getting_ids.md](../getting_ids.md#levelplay-ironsource).

| Platform | SDK (pinned) | Minimum |
|---|---|---|
| Android | `com.unity3d.ads-mediation:mediation-sdk:9.7.0` (+ `play-services-appset` 16.1.0, `play-services-ads-identifier` 18.3.0: newer than the documented 16.0.0 / 18.1.0; `play-services-basement` comes transitively) | API 19 (project: 24) |
| iOS | LevelPlay 9.7.0 (Swift Package Manager: `ironsource-mobile/LevelPlay-Swift-Package`, product `UnityMediationSDK`) | iOS 12 per the vendor (project: 13); Xcode 16+ (swift-tools 6.0); 9.6.1+ is needed for Xcode 27 |

Only the **LevelPlay 9.x ad-unit APIs** are used. 9.0 removed every legacy `IronSource.*` API.

> **ironSource Ads direct demand was sunset on 30 April 2026** ([announcement](https://unity.com/products/ironsource-ads-sunset)).
> LevelPlay mediation (what this adapter uses) continues, but an app gets fill **only from the networks enabled in LevelPlay**
> (Unity recommends Unity Ads bidding), and each enabled network's LevelPlay adapter must be added to the app. See
> [doc/getting_ids.md](../getting_ids.md#levelplay-ironsource) step 4.

## Config

```dart
AdNetwork.ironsource: NetworkConfig(
  appId: '<LevelPlay app key>',
  bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…',
  extras: {'userId': 'optional-user-id'},
),
```

- **Do not enable Unity Ads at the same time.** The Unity SDK initializes only once per process, so unified_ads skips
  `unity` with `configConflict` when both are enabled. Get Unity demand through LevelPlay mediation instead.
- **Test mode** (`TestModeSupport.testSuiteOnly`): LevelPlay has no test-ads flag. Use the LevelPlay test suite
  (`is_test_suite` meta-data, then launch the test suite) or dashboard test devices. unified_ads logs a reminder.
- **Rewarded:** `LevelPlayReward(name, amount)` maps to `RewardItem(amount, name)`. The reward **can arrive after the close
  event**, and unified_ads delivers it either way.
- **Banner sizes:** `LevelPlayAdSize.BANNER / LARGE / MEDIUM_RECTANGLE / LEADERBOARD`. Adaptive sizes use
  `createAdaptiveAdSize(context, width)`. Sizes are set only through the banner config builder.
- Ad objects are created only after LevelPlay init succeeds; unified_ads guarantees this ordering.

## Privacy

- `consentGiven` sets `LevelPlayPrivacySettings.setGDPRConsent`, `ccpaOptOut` sets `setCCPA`, and `coppa` sets `setCOPPA`. These are applied
  before init, as LevelPlay requires.
- Google UMP and IAB TCF strings are read automatically.

## Platform notes

- **Android:**
  - Maven Central. The AAR ships its ProGuard rules and merges its activities and providers. Lifecycle tracking is automatic.
  - Declare `com.google.android.gms.permission.AD_ID` when targeting API 33+.
  - The SDK pulls in `adquality-sdk` with an open version range. Pin it in the app if you need reproducible builds.
- **iOS:**
  - `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = YES`, per the LevelPlay docs. **Flag this for App Store review.**
  - `SKAdNetworkItems` (`su67r6k2v3.skadnetwork` plus each mediated network's IDs).
  - Optionally `NSAdvertisingAttributionReportEndpoint = https://postbacks-is.com/`.
  - **LevelPlay needs `-ObjC`: add it to Runner → Build Settings → Other Linker Flags.** LevelPlay's own Swift package
    can't set it (its manifest says to add it to the app project, and the official SPM demo does). The adapter's
    `Package.swift` also passes it (⚠ whether that reaches the app link is to be confirmed by CI), so the Runner
    setting is the reliable one.

## Error mapping (LevelPlay error codes)

| Code | `AdErrorCode` |
|---|---|
| 509, 606, 1024, 1035, 1044, 1158 (no ads / no candidates; 1044 = banner) | `noFill` |
| 520 no internet | `networkError` |
| 524/525/526/530 capped | `frequencyCapped` |
| 624/626 missing / invalid ad unit | `invalidConfig` |
| 625 load before init | `notInitialized` |
| show: 628 / 630 / 631 (iOS: nil controller) | `notReady` / `alreadyShowing` / `noActivity` (iOS) |

## Meta (Facebook) bidding: opt-in

Audience Network only fills through **bidding**, so the way to earn Meta demand is through LevelPlay. This package
declares **no** Meta dependency. You opt in by adding the vendor's Meta adapter to **your app**. The adapter then:

- detects it at init and logs `Meta bidding adapter detected (…)` at info level;
- forwards privacy to Audience Network **before** LevelPlay initializes it.

`ConsentState.ccpaOptOut` becomes Limited Data Use. `coppa` becomes mixed audience, both directly on
`AdSettings` and through the LevelPlay metadata `Meta_Mixed_Audience` that the adapter reads (matched
case-insensitively; the docs spell it two ways).

**Android:** `android/app/build.gradle.kts`

```kotlin
dependencies {
    implementation("com.unity3d.ads-mediation:facebook-adapter:5.6.0") // brings Audience Network 6.22.0
}
```

Audience Network also needs cleartext to `127.0.0.1`. See [facebook.md](facebook.md#android).

**iOS:** iOS **15.0+** (Runner target deployment target). In Xcode, **File > Add Package Dependencies…**, add it to
the **Runner** target:

| Package | Dependency rule | Product |
|---|---|---|
| `https://github.com/ironsource-mobile/LevelPlay-Facebook-Adapter-Swift-Package` | Exact `5.6.0` | `FacebookAdapter` (brings `FBAudienceNetwork` exact 6.22.1, the same as `unified_ads_facebook` 1.1.0) |

On iOS 15–16 the adapter sets `FBAdSettings.setAdvertiserTrackingEnabled` from the ATT status before the mediation SDK
starts Audience Network (Meta requires it there, with or without mediation); on iOS 17+ Audience Network 6.15+ reads
the ATT status itself. Also add Meta's SKAdNetwork IDs.

**Dashboards:** In Monetization Manager, create the placement. In LevelPlay, go to Mediation → Setup → SDK Networks → Meta, then
*Login with Facebook*. Set the App ID (the part of the placement ID before `_`) and the Placement ID per instance, and
tell your LevelPlay account manager once bidding is live.

**Testing:** Use LevelPlay's Integration Helper and the test suite. Register test devices in Monetization Manager. Meta warns that
around 20% of test requests intentionally return no fill.

Don't also run `unified_ads_facebook` for the same placements in your waterfall. Meta discourages running more than one
mediation path for the same inventory.

Verification: `META_BIDDING=ironsource bash tool/verify_opt_in.sh android` checks that these exact lines resolve Audience Network.

## API names used

- ✅ **Android: compiler-verified** against 9.7.0:
  - `LevelPlay.init` + `LevelPlayInitRequest`
  - `LevelPlayPrivacySettings`
  - `LevelPlayInterstitialAd` / `LevelPlayRewardedAd` + listeners
  - `LevelPlayBannerAdView` + `Config.Builder` + `LevelPlayAdSize`
- Meta bidding detection (Phase 7): the adapter classes were checked in the vendor binaries:
  - Android `com.ironsource.adapters.facebook.FacebookAdapter`, from the 5.5.0 AAR (5.6.0 keeps the class);
  - iOS `ISFacebookAdapter`, from the 5.5.0 header.

  The metadata APIs were also checked: Android `LevelPlay.setMetaData` (9.6.1 AAR) and iOS
  `LevelPlay.setMetaData(withKey:value:)`: the 9.7.0 `LevelPlay.h` declares `+setMetaDataWithKey:value:` with no
  `NS_SWIFT_NAME`, and the SDK's own error message spells the Swift call this way (some Unity doc pages show
  `setMetaDataWithKey`, which doesn't compile).
- ⚠ **iOS: not yet compiled.**
  - `LPMAdSize.banner()` and `createAdaptive()` are confirmed by the official demo.
  - `large()`, `mediumRectangle()` and `leaderBoard()` are importer-derived.
