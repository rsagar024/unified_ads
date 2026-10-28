# unified_ads_admob

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_admob.svg)](https://pub.dev/packages/unified_ads_admob)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

Google AdMob adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial, rewarded,
rewarded interstitial and app open** ads, plus a Google UMP `ConsentProvider`. Adding this package links **only** the
Google Mobile Ads SDK and UMP into your app.

| | Android | iOS |
|---|---|---|
| SDK | GMA Next-Gen `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.5.0`, UMP `user-messaging-platform:4.0.0` | `GoogleMobileAds` 13.11.0, `GoogleUserMessagingPlatform` 3.1.0 |
| Minimum | API 24, compileSdk 35+ | iOS 13, Xcode 26.2+ |
| Distribution | Gradle | Swift Package Manager (`googleads/swift-package-manager-google-mobile-ads`, `…-google-user-messaging-platform`) |

> **Android uses the GMA Next-Gen SDK**, which can't share an app with the legacy `play-services-ads` (for example, the
> official `google_mobile_ads` plugin, or a Google mediation adapter that pulls it). Exclude the legacy SDK if
> anything brings it in.

## Install and use

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_admob: ^1.1.0
```

```dart
await UnifiedAds.requestTrackingAuthorization();              // iOS prompt; Android: notApplicable
await UnifiedAds.gatherConsent(const AdmobConsentProvider()); // UMP form if required
await UnifiedAds.init(AdConfig(
  testMode: true,
  networks: {
    AdNetwork.admob: NetworkConfig(
      appId: PlatformValue.select(android: 'ca-app-pub-…~…', ios: 'ca-app-pub-…~…'),
      bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…',
      rewardedInterstitialAdUnitId: '…',   // RewardedInterstitialAd
      appOpenAdUnitId: '…',                // AppOpenAd
      testDeviceIds: ['<hashed device id from the log>'],
    ),
  },
));
```

## Getting the IDs

You need: App ID per platform + one ad unit ID per format.

1. **Account:** sign in at [admob.google.com](https://admob.google.com), choose your country (can't be changed later),
   accept the terms, verify a phone number and submit payment details. Verification takes up to 24 hours.
2. **App:** **Apps → Add app** → Android or iOS. Published: search the store listing. Not published: enter a name and
   link the store later. Each app goes through a **readiness review** (2–3 days) once it's published and linked.
3. **App ID:** **Apps → View all apps** → copy the **App ID** column. Format `ca-app-pub-…~…` (note the **`~`**).
4. **Ad units:** **Apps → your app → Ad units → Add ad unit** → **Banner**, **Interstitial** or **Rewarded** (set the
   reward amount and item; they become your `RewardItem`) → **Create ad unit**. Format `ca-app-pub-…/…` (note the **`/`**).
5. **Testing:** **Settings → Test devices**, or put the hashed ID the SDK prints to logcat / Xcode console into
   `testDeviceIds`. Google's demo ad units always serve test ads.
6. **Consent:** **Privacy & messaging** → create a **GDPR** message (and a **US state regulations** message if needed).
   `AdmobConsentProvider` shows them.
7. **app-ads.txt:** **Apps → View all apps → app-ads.txt** → copy your line
   (`google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`) to `https://<your-domain>/app-ads.txt`.

## Android setup

`android/app/src/main/AndroidManifest.xml`, inside `<application>` (**required**):

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
```

- The UMP consent SDK reads the App ID from the manifest, and the adapter passes the same value to GMA Next-Gen at init.
  Set `NetworkConfig.appId` to the same ID; a mismatch is logged and the manifest value wins.
- `minSdk = 24`. Permissions (`INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID`) are merged from the SDK. To opt out of AD_ID:
  `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>`.
- R8 rules ship with the SDK and the adapter. No cleartext / network security config is needed.

## iOS setup

`ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
<key>SKAdNetworkItems</key>
<array>
  <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
  <!-- + every ID from https://developers.google.com/admob/ios/3p-skadnetworks -->
</array>
```

- If `GADApplicationIdentifier` is missing, `UnifiedAds.init` reports `invalidConfig` for AdMob instead of crashing.
- Deployment target **13.0** on the Runner target. Swift Package Manager only (since 1.1.0).
- Google's frameworks ship their own privacy manifests; the adapter declares its `UserDefaults` use (reason `CA92.1`).

## Consent (UMP)

- Create the consent message in the AdMob console (**Privacy & messaging**). Without one UMP logs a form error and the
  flow continues.
- UMP writes the IAB TCF / GPP strings; AdMob, MAX, LevelPlay and InMobi read them directly, and `AdmobConsentProvider`
  turns them into a `ConsentState` for the other adapters.
- Offer "Privacy settings" when `await provider.isPrivacyOptionsRequired()`, calling `provider.showPrivacyOptions()`.
- Testing: `AdmobConsentProvider(debugGeography: UmpDebugGeography.eea, testDeviceHashedIds: ['<hash>'])`.
- `ccpaOptOut: true` sets `gad_rdp` (restricted data processing); `coppa: true` sets `AgeRestrictedTreatment.CHILD`.

## Formats and test mode

- `TestModeSupport.testDevices`: test ads go to registered `testDeviceIds` and to all emulators / simulators. Google's
  demo ad unit IDs always serve test ads (never ship them).
- Banner: standard, large, MREC, leaderboard, adaptive anchored (`getLargeAnchoredAdaptiveBannerAdSize` /
  `largeAnchoredAdaptiveBanner`) and adaptive inline. Plus interstitial, rewarded, **rewarded interstitial** and **app open**.
- Google demo IDs: rewarded interstitial Android `ca-app-pub-3940256099942544/5354046379`, iOS `…/6978759866`; app open
  Android `…/9257395921`, iOS `…/5575463023`.

## Error mapping

Android (Next-Gen) reports enum codes (`AdError.nativeCode` is the enum name); iOS reports integers.

| SDK code (Android Next-Gen / iOS) | `AdErrorCode` |
|---|---|
| `NO_FILL` / noFill 1 | `noFill` |
| `NETWORK_ERROR` / networkError 2, serverError 3 | `networkError` |
| `TIMEOUT` / timeout 5 | `timeout` |
| `INVALID_REQUEST`, `APP_ID_MISSING`, `NOT_FOUND` / invalidRequest 0, invalidArgument 12, appIdMissing 20, invalidAdString 21 | `invalidConfig` |
| show: `AD_REUSED`, `H5_SHOW_AD_NOT_LOADED` / adAlreadyUsed 19 | `notReady` |
| show: `APP_NOT_FOREGROUND` | `noActivity` |
| anything else | `internal` / `showFailed` |

## Meta (Facebook) bidding: opt-in

This package declares **no** Meta dependency. Add Google's Meta adapter to **your app** and the adapter detects it at init
and forwards privacy (`ccpaOptOut` → Limited Data Use, `coppa` → mixed audience) before AdMob initializes it.

```kotlin
// android/app/build.gradle.kts
dependencies {
    implementation("com.google.ads.mediation:facebook:6.22.0.1")
}
// Required: Google's Meta adapter depends on the legacy SDK, which can't coexist with GMA Next-Gen.
configurations.configureEach {
    exclude(group = "com.google.android.gms", module = "play-services-ads")
    exclude(group = "com.google.android.gms", module = "play-services-ads-lite")
}
```

iOS (15.0+): in Xcode, **File → Add Package Dependencies…** → `https://github.com/googleads/googleads-mobile-ios-mediation-meta`,
rule **Commit** `0a3d0597402162334fb5e11816ca612478180095` (= tag `6.22.000`, not valid semver), product `MetaAdapterTarget`,
on the **Runner** target. Add Meta's SKAdNetwork IDs and the Android `127.0.0.1` cleartext config. In Monetization Manager
pick **Google AdMob** as the mediation partner; in AdMob add **Meta Audience Network** under *Bidding* in a mediation
group. Test with Ad Inspector single-source testing.

## Status

Android verified on a physical device (all five formats load with test ads; banner rendered, interstitial shown). iOS
builds in CI (`flutter build ios --no-codesign`) and hasn't run on a physical device yet. New adapters copy this
package: see [`TEMPLATE.md`](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads_admob/TEMPLATE.md).

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
