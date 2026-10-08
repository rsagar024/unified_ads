# AdMob setup (`unified_ads_admob`)

> **Getting the IDs:** how to create the account, app and every ID for this network is in
> [docs/getting_ids.md](../getting_ids.md#admob).

SDKs (pinned, see [`SDK_STATUS.md`](../../SDK_STATUS.md) §2.1):

| Platform | SDK | Consent (UMP) |
|---|---|---|
| Android | **GMA Next-Gen** `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.5.0` | `com.google.android.ump:user-messaging-platform:4.0.0` |
| iOS | `Google-Mobile-Ads-SDK` 13.11.0 (CocoaPods / SPM) | `GoogleUserMessagingPlatform` 3.1.0 |

**Minimums:** Android minSdk **24**, compileSdk 35+, Kotlin 1.9+; iOS **13.0**, Xcode 26.2+ (⚠ per Google's release
notes; the quick-start page still says 16).

> **Android uses the GMA Next-Gen SDK**, which can't be in the same app as the legacy `play-services-ads`. If another
> dependency (for example the official `google_mobile_ads` plugin, or a Google mediation adapter) pulls the legacy SDK,
> exclude it. See [the migration note](../migration/1.0.0-admob-next-gen.md).

## 1. Add the packages

```yaml
dependencies:
  unified_ads: ^1.0.0
  unified_ads_admob: ^1.0.0
```

The adapter registers itself. No other network's SDK is pulled in.

## 2. Android

`android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
```

> The App ID **must** be in the manifest. The UMP consent SDK reads it there, and the adapter passes the same value to
> GMA Next-Gen at initialization (`InitializationConfig`). Set `NetworkConfig.appId` to the same ID; a mismatch is logged
> and the manifest value wins.

- `android/app/build.gradle.kts`: set `minSdk = 24` (or keep `flutter.minSdkVersion` if it is ≥ 24).
- Permissions (`INTERNET`, `ACCESS_NETWORK_STATE`, `com.google.android.gms.permission.AD_ID`) are merged from the SDK's
  manifest. ⚠ To opt out of AD_ID, add `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>`.
- R8/ProGuard: the SDK AARs ship their own consumer rules. The adapter adds a keep rule for its plugin class (and keeps
  the Meta adapter's name for detection). Nothing to add.
- Cleartext traffic / network security config: not required.

## 3. iOS

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

If `GADApplicationIdentifier` is missing, `UnifiedAds.init` reports `AdErrorCode.invalidConfig` for AdMob instead of
crashing.

- `ios/Podfile`: `platform :ios, '13.0'`.
- **CocoaPods:** works with and without `use_frameworks!`. The adapter pod is a `static_framework`, matching the
  statically linked Google Mobile Ads xcframework (⚠ static vs dynamic not stated by Google). Also compatible with
  `use_frameworks! :linkage => :static`.
- **Swift Package Manager:** supported. The adapter's `Package.swift` depends on
  `googleads/swift-package-manager-google-mobile-ads` (exact 13.11.0) and
  `googleads/swift-package-manager-google-user-messaging-platform` (exact 3.1.0).
- Privacy manifest: Google's frameworks ship their own. The adapter declares its `UserDefaults` use (reason `CA92.1`).

## 4. Consent (GDPR / US states) and ATT

Recommended order at startup: **ATT → consent → init**.

```dart
await UnifiedAds.requestTrackingAuthorization();            // iOS prompt; Android: notApplicable
await UnifiedAds.gatherConsent(const AdmobConsentProvider()); // UMP form if required
await UnifiedAds.init(config);
```

- The consent message must be created in the AdMob console (**Privacy & messaging**). Without one, UMP logs a form
  error and the flow continues.
- UMP writes the IAB TCF / GPP strings. AdMob, AppLovin MAX, LevelPlay and InMobi read them directly, and
  `AdmobConsentProvider` turns them into a `ConsentState` for the other adapters.
- Offer a "Privacy settings" entry when `await provider.isPrivacyOptionsRequired()` is true, calling
  `provider.showPrivacyOptions()`.
- **Testing UMP:** `AdmobConsentProvider(debugGeography: UmpDebugGeography.eea, testDeviceHashedIds: ['<hash from logcat/Xcode console>'])`.
- `ConsentState.ccpaOptOut == true` sets `gad_rdp` (restricted data processing) in SharedPreferences / UserDefaults.
- `ConsentState.coppa == true` sets `AgeRestrictedTreatment.CHILD`. The old tag-for-child-directed API is deprecated.

## 5. Config and test mode

```dart
AdConfig(
  testMode: true,
  networks: {
    AdNetwork.admob: NetworkConfig(
      appId: PlatformValue.select(android: 'ca-app-pub-…~…', ios: 'ca-app-pub-…~…'),
      bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…',
      testDeviceIds: ['<hashed device id from the log>'],
    ),
  },
)
```

- `TestModeSupport.testDevices`: AdMob serves test ads to registered test devices (`testDeviceIds`) and to all
  emulators and simulators. Google's **demo ad-unit IDs** always serve test ads (they are used in `example/`; never ship them).
- Formats:
  - banner: standard, large, MREC and leaderboard; adaptive anchored uses `getLargeAnchoredAdaptiveBannerAdSize` /
    `largeAnchoredAdaptiveBanner`; adaptive inline;
  - interstitial, rewarded;
  - **rewarded interstitial** (`RewardedInterstitialAd`, unit ID in `rewardedInterstitialAdUnitId`);
  - **app open** (`AppOpenAd`, unit ID in `appOpenAdUnitId`).

  Google's demo IDs for the last two:
  - rewarded interstitial: Android `ca-app-pub-3940256099942544/5354046379`, iOS `…/6978759866`;
  - app open: Android `…/9257395921`, iOS `…/5575463023`.

## 6. Error mapping

Android (Next-Gen) reports **enum** codes, and `AdError.nativeCode` is the enum name. iOS reports integers.

| SDK code (Android Next-Gen / iOS) | `AdErrorCode` |
|---|---|
| `NO_FILL` / noFill 1 | `noFill` |
| `NETWORK_ERROR` / networkError 2, serverError 3 | `networkError` |
| `TIMEOUT` / timeout 5 | `timeout` |
| `INVALID_REQUEST`, `APP_ID_MISSING`, `NOT_FOUND` / invalidRequest 0, invalidArgument 12, appIdMissing 20, invalidAdString 21 | `invalidConfig` |
| show: `AD_REUSED`, `H5_SHOW_AD_NOT_LOADED` / adAlreadyUsed 19 | `notReady` |
| show: `APP_NOT_FOREGROUND` | `noActivity` |
| anything else (`INTERNAL_ERROR`, `CANCELLED`, `MEDIATION_SHOW_ERROR`, …) | `internal` / `showFailed` |

The original SDK code is always available in `AdError.nativeCode`.

## 7. Meta (Facebook) bidding: opt-in

Audience Network only fills through **bidding**, so the way to earn Meta demand is through AdMob mediation.
`unified_ads_admob` declares **no** Meta dependency. You opt in by adding Google's Meta adapter to **your app**. The
adapter then:

- detects it at init and logs `Meta bidding adapter detected (…)` at info level;
- forwards privacy to Audience Network **before** AdMob initializes it:
  - `ConsentState.ccpaOptOut` becomes Limited Data Use;
  - `coppa` becomes mixed audience;
  - AdMob's own `AgeRestrictedTreatment.CHILD` is also mapped by Google's adapter.

**Android:** `android/app/build.gradle.kts`

```kotlin
dependencies {
    implementation("com.google.ads.mediation:facebook:6.22.0.1")
}
// Required: Google's Meta adapter depends on the legacy Google Mobile Ads SDK, which
// can't coexist with GMA Next-Gen.
configurations.configureEach {
    exclude(group = "com.google.android.gms", module = "play-services-ads")
    exclude(group = "com.google.android.gms", module = "play-services-ads-lite")
}
```

Audience Network also needs cleartext to `127.0.0.1`. See [facebook.md](facebook.md#android).

**iOS:** CocoaPods or Swift Package Manager, iOS **15.0+**.

```ruby
# ios/Podfile, inside `target 'Runner'`, and `platform :ios, '15.0'`
pod 'GoogleMobileAdsMediationFacebook', '6.22.0.0'
```

With SwiftPM, add `https://github.com/googleads/googleads-mobile-ios-mediation-meta.git` (product `MetaAdapterTarget`)
to the Runner target in Xcode. ⚠ Google publishes it on the `main` branch without tags, so CocoaPods is the more
reproducible route. Also add Meta's SKAdNetwork IDs.

The adapter does **not** call `FBAdSettings.setAdvertiserTrackingEnabled`. Since FAN 6.15, on iOS 17+ the SDK reads the
ATT status itself.

**Dashboards:**
- In Meta Monetization Manager, create a property and placement, and choose **Google AdMob** as the mediation partner.
- In AdMob, create a mediation group for the ad unit and add **Meta Audience Network** under *Bidding*. Map the
  Placement ID, and add Meta to the EU and US-states ad partner lists.

**Testing:**
- Register the device in AdMob and enable testing in Monetization Manager.
- Use Ad Inspector's single-source testing on "Meta Audience Network (Bidding)".
- `IMG_16_9_APP_INSTALL#` test placements don't apply through bidding.

Don't also run `unified_ads_facebook` for the same placements in your waterfall. Meta discourages running more than one
mediation path for the same inventory.

Verification: `META_BIDDING=admob bash tool/verify_opt_in.sh android` checks that these exact lines resolve Audience
Network while keeping the legacy SDK out.
