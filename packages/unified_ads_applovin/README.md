# unified_ads_applovin

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_applovin.svg)](https://pub.dev/packages/unified_ads_applovin)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

AppLovin MAX adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial, rewarded and
app open** ads. Adding this package links **only** the AppLovin MAX SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.applovin:applovin-sdk:13.6.4` | `AppLovinSDK` 13.6.4 |
| Minimum | **API 24** (13.6.3+) | iOS 13 (SDK: 12) |
| Distribution | Gradle (Maven Central) | Swift Package Manager (`AppLovin/AppLovin-MAX-Swift-Package`, product `AppLovinSDK`) |

## Install and use

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_applovin: ^1.1.0
```

```dart
await UnifiedAds.init(AdConfig(
  testMode: true,
  networks: {
    AdNetwork.applovin: NetworkConfig(
      appId: '<MAX SDK key>',                 // passed in code; no manifest/plist key needed
      bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…',
      appOpenAdUnitId: '…',                   // App open (MAX has no rewarded interstitial)
      testDeviceIds: ['<GAID / IDFA>'],       // used when test mode is on
    ),
  },
));
```

## Getting the IDs

You need: SDK key + one MAX ad unit ID per format and platform.

1. **Account:** sign up at [dash.applovin.com/signup](https://dash.applovin.com/signup). Account approval may be
   required (use the same email as your store listing). Set payments and your website domain.
2. **SDK key:** **Account → General → Keys** → copy the **SDK Key** (`appId`).
3. **Ad units:** **MAX → Mediation → Manage → Ad Units → Create Your Ad Unit** → name, platform, format (**Banner**,
   **Interstitial**, **Rewarded**, or **MRec** for `BannerSize.mediumRectangle`) → find your app or **Manually Add Your
   Package Name**. The package name / bundle ID is **case-sensitive** and must match exactly. `AppOpenAd` needs an
   App Open unit (`appOpenAdUnitId`; ⚠ AppLovin's help page doesn't list App Open; ask your account manager if your
   dashboard doesn't offer it).
4. **Testing:** put your GAID / IDFA in `testDeviceIds` with `testMode: true`; the **Mediation Debugger** can force test
   ads. If every MAX load **times out**, the SDK key or package name is wrong (MAX reports no error for an invalid key).

## Notes

- **Test mode** (`TestModeSupport.testDevices`): `testDeviceIds` are registered as MAX test devices when `testMode` is on.
  MAX has no public demo ad units, so you need a dashboard app with real ad units. The Mediation Debugger helps validate.
- **Banner sizes:** standard = a fixed 320×50 `MaxAdFormat.BANNER`, MREC = `MaxAdFormat.MREC`, leaderboard =
  `MaxAdFormat.LEADER`; adaptive anchored / inline opt in through `MaxAdViewConfiguration` / `MAAdViewConfiguration`
  (`ANCHORED` / `INLINE`, MAX 13.2.0+). The resolved size comes from `MaxAd.size`.
- **Context-free APIs:** MAX 13.3.0 deprecated every API that takes a `Context`; the adapter uses only the new forms.
- **App open:** `AppOpenAd` loads a `MaxAppOpenAd`, which MAX presents from its own window. MAX has no rewarded
  interstitial; the waterfall skips MAX for `RewardedInterstitialAd`.
- **Impressions** come from MAX's revenue callback (`onAdRevenuePaid`, once per impression).
- **Invalid SDK key:** MAX still reports init success, then never calls the load callbacks. unified_ads' timeouts turn
  this into `AdErrorCode.timeout`. If every MAX load times out, check the SDK key and package name.
- **Rewarded ads are singletons per ad unit** in MAX; keep one rewarded ad per unit (the cache already does).

## Platform setup

- **Android:** `google()` + `mavenCentral()`. ProGuard rules are bundled; permissions (INTERNET, ACCESS_NETWORK_STATE,
  AD_ID) are merged from the SDK manifest. Nothing to add to the manifest.
- **iOS:** add the SKAdNetwork IDs from https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json (own ID
  `ludvb6z3bs.skadnetwork`) and `NSUserTrackingUsageDescription`. If MAX fails with undefined symbols or unrecognized
  selectors, add `-ObjC` to the Runner target's Other Linker Flags. The framework ships its own privacy manifest.

## Privacy

- `consentGiven` → `AppLovinPrivacySettings.setHasUserConsent`; `ccpaOptOut` → `setDoNotSell`. Both applied **before** init.
- Google UMP's TCF strings are picked up automatically (MAX 12.0+).
- **COPPA:** MAX removed COPPA support in 13.0. When `ConsentState.coppa` is true, unified_ads skips MAX
  (`configConflict`), and the adapter also refuses init.

## Error mapping (`MaxErrorCode`)

| Code | `AdErrorCode` |
|---|---|
| 204 NO_FILL | `noFill` |
| -1000 NETWORK_ERROR, -1009 NO_NETWORK | `networkError` |
| -1001 NETWORK_TIMEOUT | `timeout` |
| -5603 INVALID_AD_UNIT_ID | `invalidConfig` |
| show: -23 already showing / -24 not ready / -5602 (Android) or -25 (iOS invalid view controller) | `alreadyShowing` / `notReady` / `noActivity` |
| other | `internal` / `showFailed` |

## Meta (Facebook) bidding: opt-in

This package declares **no** Meta dependency. Add AppLovin's Meta adapter to **your app**; the adapter detects it at init
and forwards privacy (`ccpaOptOut` → Limited Data Use via `AdSettings.setDataProcessingOptions`, `coppa` → mixed
audience) before MAX initializes it.

```kotlin
// android/app/build.gradle.kts
dependencies {
    implementation("com.applovin.mediation:facebook-adapter:6.22.0.1") // brings Audience Network 6.22.0
}
```

iOS (15.0+): **File → Add Package Dependencies…** → `https://github.com/AppLovin/AppLovin-MAX-Swift-Package-Meta`, exact
`6220100.0.0` (pins `FBAudienceNetwork` 6.22.1), product `AppLovinMediationFacebookAdapter`, on the **Runner** target. Add Meta's SKAdNetwork IDs and the
Android `127.0.0.1` cleartext config. Select Meta as a bidder on your MAX ad units and list AppLovin as the mediation
partner in Monetization Manager. On iOS 15–16 the adapter also sets `FBAdSettings.setAdvertiserTrackingEnabled` from the ATT status (Meta requires it below iOS 17).

## Status

Android compiles and runs on a device; there are no public MAX credentials, so serving needs your own SDK key and ad
units. iOS builds in CI and hasn't run on a physical device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
