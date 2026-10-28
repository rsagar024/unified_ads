# unified_ads_ironsource

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_ironsource.svg)](https://pub.dev/packages/unified_ads_ironsource)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

ironSource / Unity LevelPlay adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial
and rewarded** ads. Adding this package links **only** the LevelPlay SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.unity3d.ads-mediation:mediation-sdk:9.6.1` (+ `play-services-appset` 16.1.0, `play-services-ads-identifier` 18.3.0) | `IronSourceSDK` 9.6.1.0 |
| Minimum | API 19 (package: 24) | iOS 13 |
| Distribution | Gradle (Maven Central) | Swift Package Manager (`ironsource-mobile/LevelPlay-Swift-Package`, product `UnityMediationSDK`) |

Only the **LevelPlay 9.x ad-unit APIs** are used; 9.0 removed every legacy `IronSource.*` API.

> **ironSource Ads direct demand was sunset on 30 April 2026.** LevelPlay mediation (what this adapter uses) continues,
> but fill comes **only from the networks enabled in LevelPlay** (Unity recommends Unity Ads bidding), and each enabled
> network's LevelPlay adapter must be added to your app (Gradle / Swift package on the Runner target).

## Install and use

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_ironsource: ^1.1.0
```

```dart
await UnifiedAds.init(AdConfig(
  networks: {
    AdNetwork.ironsource: NetworkConfig(
      appId: PlatformValue.select(android: '<Android App Key>', ios: '<iOS App Key>'),
      bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…',
      extras: {'userId': 'optional-user-id'},
    ),
  },
));
```

## Getting the IDs

You need: App Key + ad unit ID per format + at least one demand network.

> **ironSource Ads direct demand was sunset on 30 April 2026.** LevelPlay mediation continues, but fill comes only from
> the **networks you enable in LevelPlay** (Unity recommends Unity Ads bidding). An app with no networks enabled gets **no fill**.

1. **Account:** [platform.ironsrc.com/partners/signup](https://platform.ironsrc.com/partners/signup); answer the verification emails.
2. **App + App Key:** **New App** → import from the store URL or enter a temporary name → set COPPA / CCPA → the **App Key** is on the **Apps** page.
3. **Ad units:** **Ad units → Create ad unit** → name → format → **Save**. The ad unit ID is in the table.
4. **Demand:** **Mediation → Setup → SDK Networks** → e.g. **Unity Ads** (API Key + Organization core ID) → per app
   **Add bidder**. Other networks: **Instances → Add instance → Active**. Each enabled network's LevelPlay adapter must
   also be added to your app (Gradle / Swift package on the Runner target).
5. **Testing:** **LevelPlay → Settings → Test devices**, or the integration test suite (`is_test_suite` meta-data).

## Notes

- **Don't enable Unity Ads at the same time.** The Unity SDK initializes once per process, so unified_ads skips `unity`
  with `configConflict`. Get Unity demand through LevelPlay.
- **Test mode** (`TestModeSupport.testSuiteOnly`): LevelPlay has no test-ads flag. Use the LevelPlay test suite
  (`is_test_suite` meta-data) or dashboard test devices. unified_ads logs a reminder.
- **Rewarded:** `LevelPlayReward(name, amount)` → `RewardItem(amount, name)`. The reward can arrive after the close
  event; unified_ads delivers it either way.
- **Banner sizes:** `LevelPlayAdSize.BANNER / LARGE / MEDIUM_RECTANGLE / LEADERBOARD`; adaptive uses
  `createAdaptiveAdSize(context, width)`.
- Ad objects are created only after LevelPlay init succeeds; unified_ads guarantees this ordering.

## Platform setup

- **Android:** the AAR ships its ProGuard rules and merges its activities and providers. Declare
  `com.google.android.gms.permission.AD_ID` when targeting API 33+. The SDK pulls `adquality-sdk` with an open version
  range; pin it in the app for reproducible builds.
- **iOS:** `SKAdNetworkItems` (`su67r6k2v3.skadnetwork` plus each mediated network's IDs), `NSUserTrackingUsageDescription`,
  optionally `NSAdvertisingAttributionReportEndpoint = https://postbacks-is.com/`. The LevelPlay docs set
  `NSAllowsArbitraryLoads = YES`; flag it for App Store review (not required by this plugin). **LevelPlay needs `-ObjC`**:
  the adapter's `Package.swift` passes it; if you see undefined symbols, add `-ObjC` to the Runner target's Other Linker Flags.

## Privacy

`consentGiven` → `LevelPlayPrivacySettings.setGDPRConsent`, `ccpaOptOut` → `setCCPA`, `coppa` → `setCOPPA`, applied before
init. Google UMP / IAB TCF strings are read automatically.

## Error mapping (LevelPlay error codes)

| Code | `AdErrorCode` |
|---|---|
| 509, 606, 1024, 1035, 1044, 1158 (no ads / no candidates) | `noFill` |
| 520 no internet | `networkError` |
| 524/525/526/530 capped | `frequencyCapped` |
| 624/626 missing / invalid ad unit | `invalidConfig` |
| 625 load before init | `notInitialized` |
| show: 628 / 630 / 631 (iOS: nil controller) | `notReady` / `alreadyShowing` / `noActivity` |

## Meta (Facebook) bidding: opt-in

This package declares **no** Meta dependency. Add LevelPlay's Meta adapter (and, on Android, Audience Network) to **your
app**; the adapter detects it and forwards privacy (`ccpaOptOut` → Limited Data Use, `coppa` → mixed audience, also via
the LevelPlay metadata `Meta_Mixed_Audience`) before LevelPlay initializes it.

```kotlin
// android/app/build.gradle.kts
dependencies {
    implementation("com.unity3d.ads-mediation:facebook-adapter:5.5.0")
    // LevelPlay's Meta adapter declares no dependencies: add Audience Network yourself.
    implementation("com.facebook.android:audience-network-sdk:6.22.0")
}
```

iOS (15.0+): **File → Add Package Dependencies…** →
`https://github.com/ironsource-mobile/LevelPlay-Facebook-Adapter-Swift-Package`, exact `5.5.0`, product `FacebookAdapter`
(brings `FBAudienceNetwork` 6.22.0), on the **Runner** target. Add Meta's SKAdNetwork IDs and the Android `127.0.0.1`
cleartext config. In LevelPlay: Monetize → Setup → SDK Networks → Meta → *Login with Facebook*, then set the App ID and
Placement ID per instance. Meta warns that about 20% of test requests intentionally return no fill.

## Status

Android: the SDK initializes and requests round-trip on a device; LevelPlay's demo key returns no fill for this
package, so serving needs your own app key and enabled networks. iOS builds in CI and hasn't run on a physical device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
