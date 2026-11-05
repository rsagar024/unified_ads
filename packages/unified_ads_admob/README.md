# unified_ads_admob 📱

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_admob.svg)](https://pub.dev/packages/unified_ads_admob)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

Google AdMob adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial, rewarded,
rewarded interstitial and app open** ads, plus a Google UMP `ConsentProvider`. Adding this package links **only** the
Google Mobile Ads SDK and UMP into your app.

## ✨ Features

- 🎯 **No hardcoding:** App ID and ad unit IDs live in your `AdConfig` (or `ads_config.json`). The package holds no
  real IDs.
- 🧩 **Five formats, one API:** `BannerAd` + `UnifiedBannerWidget`, `InterstitialAd`, `RewardedAd`,
  `RewardedInterstitialAd` and `AppOpenAd`. Every ad reports the network that served it (`servedBy`).
- 🌊 **Waterfall fallback:** if AdMob has no fill, unified_ads tries the next network in your `waterfall`
  automatically.
- 🛡️ **Safe test mode:** `testMode: true` sends test ads to registered test devices and to every emulator or
  simulator.
- ⏱️ **Pacing and frequency caps:** set a cooldown between interstitials, show one every N user actions, skip the
  first seconds after launch, and cap shows per time window.
- 👑 **Pro users and ad-free mode:** `UnifiedAds.setAdFree(true)` collapses banners and blocks interstitials. Rewarded
  ads stay available unless you block them too.
- 🔐 **Consent built in:** `AdmobConsentProvider` runs Google UMP (GDPR / US states) and passes the result to every
  other network.
- 🪶 **Opt-in linking:** only GMA and UMP are added to your APK / IPA. Networks you don't add are never linked.

| | Android | iOS |
|---|---|---|
| SDK | GMA Next-Gen `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.6.0`, UMP `user-messaging-platform:4.0.0` | `GoogleMobileAds` 13.11.0, `GoogleUserMessagingPlatform` 3.1.0 |
| Minimum | API 24, compileSdk 35+ | iOS 13, Xcode 26.2+ |
| Distribution | Gradle | Swift Package Manager (`googleads/swift-package-manager-google-mobile-ads`, `…-google-user-messaging-platform`) |

> **Android uses the GMA Next-Gen SDK**, which can't share an app with the legacy `play-services-ads` (for example, the
> official `google_mobile_ads` plugin, or a Google mediation adapter that pulls it). Exclude the legacy SDK if
> anything brings it in.

## 🚀 Getting Started

### 1. Add the dependency

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_admob: ^1.1.0
```

### 2. Platform setup

#### Android (`android/app/src/main/AndroidManifest.xml`)

Inside `<application>` (**required**):

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

#### iOS (`ios/Runner/Info.plist`)

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

## 📖 Usage

### 1. Initialize at app launch

Call this in `main()` before `runApp`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_admob/unified_ads_admob.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await UnifiedAds.setAdFree(await isProUser());               // optional, see step 5
  await UnifiedAds.requestTrackingAuthorization();              // iOS prompt; Android: notApplicable
  await UnifiedAds.gatherConsent(const AdmobConsentProvider()); // UMP form if required
  await UnifiedAds.init(AdConfig(
    testMode: kDebugMode,
    waterfall: [AdNetwork.admob],   // add more networks here for fallback
    networks: {
      AdNetwork.admob: NetworkConfig(
        appId: PlatformValue.select(android: 'ca-app-pub-…~…', ios: 'ca-app-pub-…~…'),
        bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…',
        rewardedInterstitialAdUnitId: '…',   // RewardedInterstitialAd
        appOpenAdUnitId: '…',                // AppOpenAd
        testDeviceIds: ['<hashed device id from the log>'],
      ),
    },
    // Interstitial timing: no ad in the first 30 s, at least 15 s between ads,
    // and only after every 3 recorded actions.
    pacing: {
      AdFormat.interstitial: AdPacing(
        initialDelay: Duration(seconds: 30),
        minInterval: Duration(seconds: 15),
        showEveryActions: 3,
      ),
    },
  ));

  runApp(const MyApp());
}
```

### 2. Display a banner ad

```dart
final banner = BannerAd(size: const BannerSize.adaptiveAnchored());

// In build():
UnifiedBannerWidget(ad: banner, anchored: true)

// In dispose():
banner.dispose();
```

The widget loads the banner when it is laid out and takes no space if every network fails or ads are switched off.

### 3. Show paced interstitial ads

Record user actions (finishing a level, saving an item, changing screens). An interstitial then shows only when the
`AdPacing` rules allow it:

```dart
final interstitial = InterstitialAd(onClosed: (ad) => goToNextScreen());
await interstitial.load();

// Later, at a natural break:
await UnifiedAds.recordAction();
if (await interstitial.canShow()) {
  await interstitial.show();     // onClosed continues the flow
} else {
  goToNextScreen();              // paced, capped or ad-free: skip silently
}
```

`show()` never contacts the network while a rule isn't met. It fails with `AdErrorCode.frequencyCapped`, and the
message names the rule (cooldown, actions or initial delay). The ad stays loaded for the next break.

### 4. Show rewarded video ads

```dart
final rewarded = RewardedAd(
  onEarnedReward: (ad, reward) => grantCoins(reward.amount, reward.type),
  onFailedToShow: (ad, error) => debugPrint('Ad failed: ${error.message}'),
);
if ((await rewarded.load()).isSuccess) await rewarded.show();
```

`RewardedInterstitialAd` works the same way. `AppOpenAd` is usually shown on app resume (pace it with
`pacing: {AdFormat.appOpen: …}`); see the "API overview" in the
[core README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md).

### 5. Pro users / ad-free mode

```dart
await UnifiedAds.setAdFree(true);                      // after a purchase
await UnifiedAds.setAdFree(true, blockRewarded: true); // block rewarded ads too
await UnifiedAds.setAdFree(false);                     // subscription ended
```

While ads are off, displayed banners collapse, and interstitial / app open `load()` and `show()` return
`AdErrorCode.adsBlocked` without a network request. The switch survives re-init but not an app restart, so call it at
startup with the user's purchase state.

## 🔑 Getting the IDs

You need: App ID per platform + one ad unit ID per format.

1. **Account:** sign in at [admob.google.com](https://admob.google.com), choose your country (can't be changed later),
   accept the terms, verify a phone number and submit payment details. Verification takes up to 24 hours.
2. **App:** **Apps → Add app** → Android or iOS. Published: search the store listing. Not published: enter a name and
   link the store later. Each app goes through a **readiness review** (2–3 days) once it's published and linked.
3. **App ID:** **Apps → View all apps** → copy the **App ID** column. Format `ca-app-pub-…~…` (note the **`~`**).
4. **Ad units:** **Apps → your app → Ad units → Add ad unit** → **Banner**, **Interstitial** or **Rewarded** (set the
   reward amount and item; they become your `RewardItem`) → **Create ad unit**. Format `ca-app-pub-…/…` (note the **`/`**).
   For the stretch formats, also create **Rewarded interstitial** (`rewardedInterstitialAdUnitId`) and **App open**
   (`appOpenAdUnitId`) units.
5. **Testing:** **Settings → Test devices**, or put the hashed ID the SDK prints to logcat / Xcode console into
   `testDeviceIds`. Google's demo ad units always serve test ads.
6. **Consent:** **Privacy & messaging** → create a **GDPR** message (and a **US state regulations** message if needed).
   `AdmobConsentProvider` shows them.
7. **app-ads.txt:** **Apps → View all apps → app-ads.txt** → copy your line
   (`google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`) to `https://<your-domain>/app-ads.txt`.

## ⚙️ Details

### Consent (UMP)

- Create the consent message in the AdMob console (**Privacy & messaging**). Without one UMP logs a form error and the
  flow continues.
- UMP writes the IAB TCF / GPP strings; AdMob, MAX, LevelPlay and InMobi read them directly, and `AdmobConsentProvider`
  turns them into a `ConsentState` for the other adapters.
- Offer "Privacy settings" when `await provider.isPrivacyOptionsRequired()`, calling `provider.showPrivacyOptions()`.
- Testing: `AdmobConsentProvider(debugGeography: UmpDebugGeography.eea, testDeviceHashedIds: ['<hash>'])`.
- `ccpaOptOut: true` sets `gad_rdp` (restricted data processing); `coppa: true` sets `AgeRestrictedTreatment.CHILD`.

### Formats and test mode

- `TestModeSupport.testDevices`: test ads go to registered `testDeviceIds` and to all emulators / simulators. Google's
  demo ad unit IDs always serve test ads (never ship them).
- Banner: standard, large, MREC, leaderboard, adaptive anchored (`getLargeAnchoredAdaptiveBannerAdSize` /
  `largeAnchoredAdaptiveBanner`) and adaptive inline (on Android `bannerAdRefreshCallback` re-reports the height when
  an inline-adaptive banner refreshes). Plus interstitial, rewarded, **rewarded interstitial** and **app open**.
- Google demo IDs: rewarded interstitial Android `ca-app-pub-3940256099942544/5354046379`, iOS `…/6978759866`; app open
  Android `…/9257395921`, iOS `…/5575463023`.

### Error mapping

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

### Meta (Facebook) bidding: opt-in

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
group. Test with Ad Inspector single-source testing. On iOS 15–16 the adapter also sets `FBAdSettings.setAdvertiserTrackingEnabled` from the ATT status (Meta requires it below iOS 17). Google's Meta Swift package pins
`FBAudienceNetwork` exact 6.22.0 while `unified_ads_facebook` 1.1.0 pins 6.22.1, so the two can't share an iOS app.

## 🛠️ Verification & Tests

```sh
flutter test                        # adapter unit tests (mocked host API)
cd example && flutter run           # the shared example app: enable AdMob in Settings
```

Android verified on a physical device (all five formats load with test ads; banner rendered, interstitial shown). iOS
builds in CI (`flutter build ios --no-codesign`) and hasn't run on a physical device yet. New adapters copy this
package: see [`TEMPLATE.md`](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads_admob/TEMPLATE.md).

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## 📄 License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
