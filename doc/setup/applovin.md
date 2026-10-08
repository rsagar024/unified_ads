# AppLovin MAX setup (`unified_ads_applovin`)

> **Getting the IDs:** how to create the account, app and every ID for this network is in
> [doc/getting_ids.md](../getting_ids.md#applovin-max).

| Platform | SDK (pinned) | Minimum |
|---|---|---|
| Android | `com.applovin:applovin-sdk:13.6.4` | **minSdk 24** (13.6.3+) |
| iOS | `AppLovinSDK` 13.6.4 (CocoaPods; SPM `AppLovin/AppLovin-MAX-Swift-Package`, product `AppLovinSDK`) | iOS 13 (SDK: 12) |

```yaml
dependencies:
  unified_ads: ^1.0.0
  unified_ads_applovin: ^1.0.0
```

## Config

```dart
AdNetwork.applovin: NetworkConfig(
  appId: '<MAX SDK key>',                 // passed in code; no manifest/plist key needed
  bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…',
  appOpenAdUnitId: '…',                   // App open (MAX has no rewarded interstitial)
  testDeviceIds: ['<GAID / IDFA>'],       // used when test mode is on
),
```

- **Test mode** (`TestModeSupport.testDevices`): `testDeviceIds` are registered as MAX test devices when `testMode` is
  on. MAX has no public demo ad units, so you need a dashboard app with real ad units. The Mediation Debugger helps
  validate the integration.
- **Banner sizes:** standard = `MaxAdFormat.BANNER` (adaptive by default on MAX); MREC = `MaxAdFormat.MREC`; leaderboard =
  `MaxAdFormat.LEADER`; adaptive anchored / inline use `MaxAdViewConfiguration` (`ANCHORED` / `INLINE`, adaptive width,
  inline max height). The resolved size comes from `MaxAd.size`.
- **App open:** `AppOpenAd` loads a `MaxAppOpenAd`, which MAX presents from its own window (`showAd()` takes no
  Activity / view controller). MAX has no rewarded-interstitial format; the waterfall skips MAX for
  `RewardedInterstitialAd`.
- **Impressions** are reported from MAX's revenue callback (`onAdRevenuePaid`, once per impression).
- **Invalid SDK key:** MAX still reports init success, then never calls the load callbacks (seen on a device). unified_ads'
  load and banner timeouts turn this into `AdErrorCode.timeout`. If every MAX load times out, check the SDK key and package name.
- **Rewarded ads are singletons per ad unit** in MAX. Loading a second rewarded ad for the same unit takes over that
  instance, so keep one rewarded ad per unit (unified_ads' cache already does this).

## Privacy

- `ConsentState.consentGiven` sets `AppLovinPrivacySettings.setHasUserConsent`, and `ccpaOptOut` sets `setDoNotSell`. Both are
  applied **before** init, as MAX requires.
- Google UMP is picked up automatically by MAX (12.0+).
- **COPPA:** MAX removed COPPA support in SDK 13.0. When `ConsentState.coppa` is true, unified_ads skips MAX
  (`AdErrorCode.configConflict`). The adapter also refuses init, as a second line of defence.

## Platform notes

- **Android:** use `google()` + `mavenCentral()`. ProGuard rules are bundled in the AAR. Permissions (INTERNET,
  ACCESS_NETWORK_STATE, AD_ID) are merged from the SDK manifest.
- **iOS:** add the SKAdNetwork IDs from https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json and
  `NSUserTrackingUsageDescription`. The pod sets `-ObjC` itself and works with `use_frameworks!`. The framework ships its own privacy
  manifest.

## Error mapping (`MaxErrorCode`)

| Code | `AdErrorCode` |
|---|---|
| 204 NO_FILL | `noFill` |
| -1000 NETWORK_ERROR, -1009 NO_NETWORK | `networkError` |
| -1001 NETWORK_TIMEOUT | `timeout` |
| -5603 INVALID_AD_UNIT_ID | `invalidConfig` |
| show: -23 already showing / -24 not ready / -5602 (Android "don't keep activities") or -25 (iOS invalid view controller) | `alreadyShowing` / `notReady` / `noActivity` |
| other | `internal` / `showFailed` |

## Meta (Facebook) bidding: opt-in

Audience Network only fills through **bidding**, so the way to earn Meta demand is through AppLovin MAX. This package
declares **no** Meta dependency. You opt in by adding the vendor's Meta adapter to **your app**. The adapter then:

- detects it at init and logs `Meta bidding adapter detected (…)` at info level;
- forwards privacy to Audience Network **before** AppLovin MAX initializes it.

`ConsentState.ccpaOptOut` becomes Limited Data Use (`AdSettings.setDataProcessingOptions`, as AppLovin asks before MAX
init). `coppa` becomes mixed audience, but MAX itself is skipped for child-directed users.

**Android:** `android/app/build.gradle.kts`

```kotlin
dependencies {
    implementation("com.applovin.mediation:facebook-adapter:6.22.0.1") // brings Audience Network 6.22.0
}
```

Audience Network also needs cleartext to `127.0.0.1`. See [facebook.md](facebook.md#android).

**iOS:** iOS **15.0+**.

```ruby
# ios/Podfile, inside `target 'Runner'`, and `platform :ios, '15.0'`
pod 'AppLovinMediationFacebookAdapter', '6.22.0.4'
```

AppLovin also publishes the adapter as a Swift package (see AppLovin's integration manager for the URL). The adapter does not call `FBAdSettings.setAdvertiserTrackingEnabled`. Since FAN 6.15, on iOS 17+ the SDK reads the
ATT status itself. Also add Meta's SKAdNetwork IDs.

**Dashboards:** Select Meta as a bidder on your MAX ad units. Meta says existing placement IDs can be reused, and Monetization Manager must
list AppLovin as the mediation partner.

**Testing:** Use MAX test mode or the Mediation Debugger with Meta selected. Dashboard test devices in Monetization Manager also work.

Don't also run `unified_ads_facebook` for the same placements in your waterfall. Meta discourages running more than one
mediation path for the same inventory.

Verification: `META_BIDDING=applovin bash tool/verify_opt_in.sh android` checks that these exact lines resolve Audience Network.

## API names used

- ✅ **Android: compiler-verified** against 13.6.4. Only the context-free APIs are used:
  - `AppLovinSdkInitializationConfiguration.builder(key)`
  - `MaxInterstitialAd(unit)`
  - `MaxRewardedAd.getInstance(unit)`
  - `MaxAppOpenAd(unit)` + `showAd()` (Phase 7)
  - `MaxAdView(unit, …)`
  - `com.applovin.mediation.MaxAdViewConfiguration`
- ⚠ **iOS: not yet compiled** (Phase 6 CI). The names come from the 13.6.4 headers and the docs. The Swift spelling of the
  `MAAdViewConfiguration` builder needs checking. `MAAppOpenAd(adUnitIdentifier:)`, `showAd()` and the
  `delegate` / `revenueDelegate` properties were checked against the 13.6.4 `MAAppOpenAd.h` (Phase 7).
- Meta bidding detection (Phase 7): the adapter classes were checked in the vendor binaries:
  - Android `com.applovin.mediation.adapters.FacebookMediationAdapter`, from the 6.22.0.1 AAR;
  - iOS `ALFacebookMediationAdapter`, from the 6.22.0.4 xcframework header.
