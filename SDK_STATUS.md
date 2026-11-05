# SDK Status: verified research

> **Verified on:** 2026-10-07. iOS Swift packages re-verified 2026-10-12 (1.1.0: iOS is Swift Package Manager only;
> CocoaPods support and the podspecs were removed. See
> [`doc/migration/1.1.0-swift-package-manager.md`](doc/migration/1.1.0-swift-package-manager.md)).
> **Re-verified 2026-10-28 (1.1.0):** every network's Android and iOS integration guide, Maven metadata and Swift
> package releases; iOS names checked against the shipped `.swiftinterface` / headers of UnityAds 4.21.0, LevelPlay
> 9.7.0, InMobiSDK 11.5.0, StartApp 4.15.0 and FBAudienceNetwork 6.22.1 (see §3.8).
> **Method:** official vendor sources only: vendor docs and release notes, Maven Central `maven-metadata.xml`,
> CocoaPods trunk API (version research, 1.0.x), vendor GitHub repositories. Where vendor sources conflicted, the conflict is recorded.
> **Legend:** ✅ verified · ✗ not supported · ⚠ unverified / best understanding (must be confirmed when the
> adapter is implemented) · B/I/R = Banner/Interstitial/Rewarded · RI = Rewarded Interstitial
>
> Re-verify this file before every adapter release. Ad SDKs change monthly.

---

## 1. Summary

| Network | Android artifact (latest stable) | iOS SDK (latest stable) | SwiftPM package (used since 1.1.0) | Min Android API | Min iOS | B | I | R | RI | App Open | Status | **Decision** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AdMob | **GMA Next-Gen** `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.6.0` (Phase 7 moved from `play-services-ads:25.5.0`; 1.6.0 since 1.1.0) | `GoogleMobileAds` 13.11.0 | ✅ `googleads/swift-package-manager-google-mobile-ads` | **24** | 13 | ✅ | ✅ | ✅ | ✅ | ✅ | Active. Legacy Android SDK in maintenance mode, so the adapter moved to Next-Gen (see §2.1) | **Full adapter** (all 5 formats) |
| Google UMP (consent) | `com.google.android.ump:user-messaging-platform:4.0.0` | `GoogleUserMessagingPlatform` 3.1.0 | ✅ `googleads/swift-package-manager-google-user-messaging-platform` | 23 | ⚠ | n/a | n/a | n/a | n/a | n/a | Active | Used by the AdMob adapter's `ConsentProvider` |
| Unity Ads | `com.unity3d.ads:unity-ads:4.21.0` | `UnityAds` 4.21.0 | ✅ `Unity-Technologies/Unity-Ads-Swift-Package` | ≤ 23 | 13 | ✅ | ✅ | ✅ | ✗ | ✗ | Active. Static API deprecated (4.19), scheduled for removal in 5.0.0 (not released as of 2026-10-28) | **Full adapter** (instance APIs) |
| ironSource / Unity LevelPlay | `com.unity3d.ads-mediation:mediation-sdk:9.7.0` | `IronSourceSDK` 9.7.0 (SPM 9.7.0) | ✅ `ironsource-mobile/LevelPlay-Swift-Package` (product `UnityMediationSDK`) | ≤ 23 | 12 | ✅ | ✅ | ✅ | ✗⚠ | ✗⚠ | Active. Renamed to LevelPlay; 9.0 removed all `IronSource.*` APIs | **Full adapter** (LevelPlay 9.x APIs) |
| AppLovin MAX | `com.applovin:applovin-sdk:13.6.4` | `AppLovinSDK` 13.6.4 | ✅ `AppLovin/AppLovin-MAX-Swift-Package` | **24** | 12 | ✅ | ✅ | ✅ | ✗⚠ | ✅ | Active. COPPA support removed in 13.0 | **Full adapter** (+ app open, Phase 7) |
| Facebook Audience Network (branded Meta) | `com.facebook.android:audience-network-sdk:6.22.0` | `FBAudienceNetwork` 6.22.1 | ✅ `facebook/FBAudienceNetwork` | 21 (Meta changelog; AAR manifest says 14) | 15 (6.22) | ✅ | ✅ | ✅ | (✅) | ✗ | **Bidding-only since 2021.** Direct load serves test ads only; production fill needs mediation bidding | **Full adapter** (owner request, 2026-10-07; was a stub) |
| Start.io (StartApp) | `com.startapp:inapp-sdk:5.4.0` | `StartAppSDK` 4.15.0 | ✅ `StartApp-SDK/StartAppSDK-SwiftPackage` (product `StartApp`) | 23 (AAR manifest) | 11 (`Package.swift`) | ✅ | ✅ | ✅ | ✗ | ✗ (splash only) | Active. Rebranded, but artifacts keep the StartApp names | **Full adapter** |
| InMobi | `com.inmobi.monetization:inmobi-ads-kotlin:11.5.1` | `InMobiSDK` 11.5.0 | ✅ `InMobi/InMobiSDK-Swift-Package` | 21 | 12 | ✅ | ✅ | ✅ | ✗ | ✗ | Active. Java artifact `inmobi-ads` abandoned at 10.1.4 | **Full adapter** |

**Plugin-wide consequences**
- **Android minSdk = 24.** GMA Next-Gen and AppLovin MAX 13.6.3+ both require it. This supersedes the
  minSdk 23 in CLAUDE.md.
- **iOS deployment target = 13.0**, except `unified_ads_facebook`, whose `Package.swift` requires **15.0**
  (FBAudienceNetwork 6.22). An app that adds the Facebook adapter (or a Meta bidding adapter) must target iOS 15.
  The app sets it on the Runner target in Xcode.
- **Xcode floor:** AdMob iOS release notes for 13.4.0 say "minimum supported Xcode version 26.2", but the
  quick-start still says 16.0. Unity Ads needs Xcode 26.0.1+. ⚠ CI is planned for Xcode 26.2+ until verified.
- **Kotlin:** GMA Next-Gen needs Kotlin 1.9+ and InMobi 11.1+ needs Kotlin 2.x. Our toolchain uses Kotlin 2.3.20 ✅.
- **SwiftPM (1.1.0, verified 2026-10-12):** every vendor ships an official Swift package, so every adapter is
  **SPM-only** and pins it exactly in its own `Package.swift`: AdMob 13.11.0 + UMP 3.1.0, Unity Ads 4.21.0, LevelPlay
  9.7.0, MAX 13.6.4, FAN 6.22.1, Start.io 4.15.0, InMobi 11.5.0 (pins as of 1.1.0). (In 1.0.x, Start.io, InMobi and
  Unity Ads were CocoaPods-only.) InMobi and LevelPlay require `-ObjC` (both vendors' guides; their own Swift packages
  can't set it). The inmobi and ironsource manifests pass it (⚠ to be confirmed by CI) and the docs tell apps to add it
  to the Runner target too. InMobi also needs `libz`, `libsqlite3.0` and `WebKit` (linked by its manifest since 1.1.0).

---

### 1.1 Meta (Facebook) bidding adapters (Phase 7, verified 2026-10-08; updated 2026-10-28)

The app adds these itself to opt in; our packages declare no Meta dependency and only detect them (by class name) and
forward privacy. All are built for FAN 6.22.x, and all need iOS 15.

| Mediation | Android (Maven) | Brings FAN? | iOS Swift package (app adds it to the Runner target) | Detected class (Android / iOS) |
|---|---|---|---|---|
| AdMob | `com.google.ads.mediation:facebook:6.22.0.1` | yes, and also legacy `play-services-ads:25.4.0`, which **must be excluded** with Next-Gen | `https://github.com/googleads/googleads-mobile-ios-mediation-meta`, product `MetaAdapterTarget`, revision `0a3d0597402162334fb5e11816ca612478180095` (= tag `6.22.000`, not valid semver). Pod in 1.0.x: `GoogleMobileAdsMediationFacebook` 6.22.0.0 | `com.google.ads.mediation.facebook.FacebookMediationAdapter` / `GADMediationAdapterFacebook` |
| AppLovin MAX | `com.applovin.mediation:facebook-adapter:6.22.0.1` | yes | `https://github.com/AppLovin/AppLovin-MAX-Swift-Package-Meta` exact `6220100.0.0` (pins FAN exact 6.22.1; was `6220004.0.0`, FAN 6.22.0), product `AppLovinMediationFacebookAdapter`. Pod in 1.0.x: 6.22.0.4 | `com.applovin.mediation.adapters.FacebookMediationAdapter` / `ALFacebookMediationAdapter` |
| LevelPlay | `com.unity3d.ads-mediation:facebook-adapter:5.6.0` | **yes** since 5.6.0 (`audience-network-sdk:6.22.0`; 5.5.0 had an empty POM) | `https://github.com/ironsource-mobile/LevelPlay-Facebook-Adapter-Swift-Package` exact `5.6.0`, product `FacebookAdapter` (brings `FBAudienceNetwork` exact 6.22.1). Pod in 1.0.x: `IronSourceFacebookAdapter` 5.5.0.0 | `com.ironsource.adapters.facebook.FacebookAdapter` / `ISFacebookAdapter` |

- How the names were checked:
  - the class names come from the AARs / xcframework headers;
  - FAN `AdSettings.setDataProcessingOptions(String[])`, `(String[], int, int)` and `setMixedAudience(boolean)` come from
    the 6.22.0 AAR (`javap`); FAN keeps all public `com.facebook.ads.**` classes in its consumer rules;
  - the iOS `FBAdSettings` selectors `setDataProcessingOptions:`, `setDataProcessingOptions:country:state:` and the
    class property `mixedAudience` (Swift: `isMixedAudience`) come from the FAN 6.22.0 `FBAdSettings.h`;
  - LevelPlay's adapter reads the metadata key `meta_mixed_audience` (its constants, case-insensitive).
- **iOS FAN pins differ (2026-10-28):** Google's Meta package (tag `6.22.000`) pins `FBAudienceNetwork` **exact 6.22.0**;
  AppLovin's `6220100.0.0` and LevelPlay's `5.6.0` pin **exact 6.22.1**, as does `unified_ads_facebook` 1.1.0. So
  `unified_ads_facebook` 1.1.0 can't share an iOS app with AdMob's Meta adapter (Meta discourages running both paths).
- `FBAdSettings.setAdvertiserTrackingEnabled:` **is** set on iOS 15–16 (since 1.1.0) from the ATT status, through the
  runtime: Meta's ATT page says it is required on iOS 14.5–16.x "regardless of the use of mediation"; the 6.22.1 header
  deprecates it from iOS 17 (`NS_DEPRECATED_IOS(12_0, 17_0)`), where FAN 6.15+ reads `ATTrackingManager` itself.
- Sources:
  - Maven metadata / POMs: Google Maven, Maven Central;
  - CocoaPods trunk specs (1.0.x) and the vendors' Swift package repositories (1.1.0);
  - https://developers.google.com/admob/android/next-gen/mediation/meta,
    https://developers.google.com/admob/ios/mediation/meta;
  - AppLovin "preparing mediated networks";
  - LevelPlay Meta guides;
  - https://developers.facebook.com/docs/audience-network/guides/partner-mediation.

## 2. Per-network detail

### 2.1 Google AdMob (Google Mobile Ads)

| Item | Android | iOS |
|---|---|---|
| Version | GMA Next-Gen **1.6.0** (2026-10-22; legacy `play-services-ads` 25.5.0 is in maintenance mode) | 13.11.0 (2026-09-29) |
| Artifact | `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk` (Google Maven) | SPM `https://github.com/googleads/swift-package-manager-google-mobile-ads.git` (product `GoogleMobileAds`; pod `Google-Mobile-Ads-SDK` in 1.0.x) |
| Minimum | minSdk 24, compileSdk 35+, Kotlin 1.9+ (Next-Gen quick start) | iOS 13.0 (since 13.0.0), Xcode 26.2 (13.4.0 release notes; the quick start still says 16.0) |
| Sources | https://developers.google.com/admob/android/next-gen/rel-notes · https://developers.google.com/admob/android/next-gen/quick-start | https://developers.google.com/admob/ios/rel-notes · https://developers.google.com/admob/ios/quick-start |

- **Maintenance mode (Android):** the release notes say *"Google Mobile Ads SDK is in maintenance mode. For the
  latest updates and features, migrate and set up GMA Next-Gen SDK."* Next-Gen:
  `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.5.0` (GA, 2026-09-24; minSdk 24; App ID passed
  in code through `InitializationConfig.Builder`; `MobileAds.initialize()` must run on a background thread).
  Source: https://developers.google.com/admob/android/next-gen/rel-notes.
  **Owner decision (2026-10-07):** the adapter used legacy 25.5.0 at first.
  **Phase 7 (2026-10-08): the Android adapter now uses Next-Gen 1.5.0** (owner: "switch fully"); **1.6.0 since 1.1.0**
  (2026-10-28: no breaking changes; fixes `onUserEarnedReward` firing after `onAdDismissedFullScreenContent`, the
  Activity context for mediated full-screen ads, and an R8 full-mode crash). See
  [`doc/migration/1.0.0-admob-next-gen.md`](doc/migration/1.0.0-admob-next-gen.md).
  - ✅ **Resolved: legacy and Next-Gen can't coexist.** Google's migration guide requires removing `play-services-ads`
    and excluding `play-services-ads(-lite)` globally to avoid duplicate classes. Mediation adapters, which still
    depend on the legacy SDK, work through that exclusion (https://developers.google.com/admob/android/next-gen/migration,
    https://developers.google.com/admob/android/next-gen/mediation).
  - Next-Gen 1.5.0 POM: it pulls `user-messaging-platform:4.0.0` (the same pin as ours) and
    `play-services-ads-identifier`; Kotlin 1.9+. It is "Supported" until Q1 2028
    (https://developers.google.com/admob/android/next-gen/deprecation).
  - Load and event callbacks arrive on **background threads**
    (https://developers.google.com/admob/android/next-gen/migration/handle-callbacks). The adapter posts every callback to
    the main thread.
- **iOS Swift API names (v12+):** the `GAD` prefix is dropped in Swift: `MobileAds.shared`, `BannerView`, `InterstitialAd`,
  `RewardedAd`, `RewardedInterstitialAd`, `AppOpenAd`, `Request`. ⚠ Check each class name against the v12
  migration guide in Phase 3. v13.0.0 removed deprecated APIs.
- **Init:** Android (Next-Gen) `MobileAds.initialize(ctx, InitializationConfig.Builder(appId)…build(), listener)` on a
  background thread. iOS `MobileAds.shared.start()`.
- **Credentials:** the App ID **must be in the manifest / Info.plist at build time**. Android crashes at launch with
  "Missing application ID" if the meta-data is absent. On iOS `GADApplicationIdentifier` is required (⚠ the exact
  failure mode is unverified). *Consequence: a Dart `AdConfig` cannot supply the AdMob App ID at runtime. The
  setup docs make this explicit.* Ad-unit IDs are per format.
- **Formats:** banner (fixed, anchored adaptive, inline adaptive, large anchored adaptive), interstitial,
  rewarded, rewarded interstitial, app open. All are supported on both platforms.
- **Test mode:** official demo ad units (they may appear in `example/` only):

  | Format | Android | iOS |
  |---|---|---|
  | App Open | `ca-app-pub-3940256099942544/9257395921` | `ca-app-pub-3940256099942544/5575463023` |
  | Adaptive Banner | `ca-app-pub-3940256099942544/9214589741` | `ca-app-pub-3940256099942544/2435281174` |
  | Fixed Banner | `ca-app-pub-3940256099942544/6300978111` | `ca-app-pub-3940256099942544/2934735716` |
  | Interstitial | `ca-app-pub-3940256099942544/1033173712` | `ca-app-pub-3940256099942544/4411468910` |
  | Rewarded | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-3940256099942544/1712485313` |
  | Rewarded Interstitial | `ca-app-pub-3940256099942544/5354046379` | `ca-app-pub-3940256099942544/6978759866` |

  Test devices: Android `RequestConfiguration.Builder().setTestDeviceIds(...)`; iOS
  `MobileAds.shared.requestConfiguration.testDeviceIdentifiers`. Emulators are always test devices.
  Sample App IDs `ca-app-pub-3940256099942544~3347511713` (Android) / `~1458002511` (iOS) are ⚠ (long-standing
  values, not re-confirmed). Sources: https://developers.google.com/admob/android/test-ads ·
  https://developers.google.com/admob/ios/test-ads
- **Manifest / plist:** `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="…"/>`.
  `com.google.android.gms.permission.AD_ID` is merged from the library manifest ⚠. iOS: `GADApplicationIdentifier`,
  `SKAdNetworkItems`, `NSUserTrackingUsageDescription`.
- **SKAdNetwork list:** https://developers.google.com/admob/ios/3p-skadnetworks (an HTML table of about 50 IDs; no
  machine-readable file).
- **Privacy:** UMP (`ConsentInformation.requestConsentInfoUpdate`, `UserMessagingPlatform.loadAndShowConsentFormIfRequired`,
  `canRequestAds`, `privacyOptionsRequirementStatus`, `showPrivacyOptionsForm`; iOS
  `ConsentInformation.shared…`, `ConsentForm.loadAndPresentIfRequired(from:)`). UMP writes the IAB TCF/GPP strings,
  and the ads SDK reads them. **Child-directed:** `setTagForChildDirectedTreatment` and `setTagForUnderAgeOfConsent`
  are **deprecated** (Android 25.3.0, iOS 13.3.0). Use `setAgeRestrictedTreatment(AgeRestrictedTreatment.CHILD/TEEN/UNSPECIFIED)`
  (iOS `requestConfiguration.ageRestrictedTreatment`). US states: `gad_rdp = 1` in SharedPreferences, or GPP.
  Sources: https://developers.google.com/admob/android/privacy · https://developers.google.com/admob/android/targeting ·
  https://developers.google.com/admob/android/privacy/us-states
- **R8:** Play-services AARs bundle consumer rules ⚠ (not confirmed on an official page). The adapter ships no extra rules unless needed.
- **iOS linkage:** distributed as a static xcframework ⚠, linked through SPM (since 1.1.0).
- **Implementation check (Phase 7, 2026-10-08): Next-Gen Android, RI + App Open on both platforms.**
  - ✅ **Android: compiler-verified** against `ads-mobile-sdk` 1.5.0. The names were first read from the AAR with
    `javap`. Names used:
    - `MobileAds.initialize(ctx, InitializationConfig.Builder(appId).setRequestConfiguration(…).build(), listener)` (on a
      worker thread), `MobileAds.setRequestConfiguration`;
    - `RequestConfiguration.Builder().setTestDeviceIds/.setAgeRestrictedTreatment`. There is no public `toBuilder()`,
      so the configuration is rebuilt from the adapter's state;
    - `common.AdRequest.Builder(adUnitId)`;
    - `InterstitialAd` / `RewardedAd` / `rewardedinterstitial.RewardedInterstitialAd` / `appopen.AppOpenAd`
      `.load(AdRequest, AdLoadCallback<T>)`, each with `adEventCallback` (`AdEventCallback` methods);
    - `show(activity[, OnUserEarnedRewardListener])`, `Ad.destroy()`;
    - `banner.AdView(ctx).loadAd(BannerAdRequest.Builder(id, AdSize).build(), AdLoadCallback<BannerAd>)`,
      `BannerAd.adSize`, `BannerAdEventCallback`, `BannerAdRefreshCallback` (`bannerAdRefreshCallback`, 1.1.0, as
      the Next-Gen banner guide recommends), `AdView.getBannerAd()/destroy()`, `banner.AdSize.*` (same factory names
      as legacy). Re-compiled against 1.6.0 on 2026-10-28;
    - `LoadAdError.ErrorCode` / `FullScreenContentError.ErrorCode` enums.
  - ✅ **iOS RI + App Open:** checked against the 13.11.0 xcframework headers (zip SHA-256 matches the SPM manifest):
    - `NS_SWIFT_NAME(RewardedInterstitialAd)` / `(AppOpenAd)`, `load(with:request:completionHandler:)` (async form
      generated);
    - `present(from:userDidEarnRewardHandler:)` / `present(from:)`, `adReward`, `fullScreenContentDelegate`;
    - `requestConfiguration.testDeviceIdentifiers` and `.ageRestrictedTreatment` were confirmed in the same headers.
  - Meta bidding detection: the Google adapter class names were confirmed in the vendor binaries: Android
    `com.google.ads.mediation.facebook.FacebookMediationAdapter` (6.22.0.1 AAR), iOS `GADMediationAdapterFacebook` (6.22.0.0
    header).
- **Implementation check (Phase 3, 2026-10-07, legacy SDK; superseded on Android by Phase 7).**
  - ✅ **Android: compiler-verified and run on a device.** Every Android name used compiled against 25.5.0 / UMP 4.0.0, and
    the adapter ran on a physical Android 10 device (banner, interstitial and rewarded test ads). Names used:
    `MobileAds.initialize`, `getRequestConfiguration().toBuilder().setTestDeviceIds/.setAgeRestrictedTreatment(AgeRestrictedTreatment.CHILD|UNSPECIFIED)`,
    `InterstitialAd.load`/`RewardedAd.load` + load callbacks, `FullScreenContentCallback`, `show(activity[, OnUserEarnedRewardListener])`,
    `AdView`/`AdListener`, `AdSize.getLargeAnchoredAdaptiveBannerAdSize`, `getInlineAdaptiveBannerAdSize`,
    `getCurrentOrientationInlineAdaptiveBannerAdSize`, `UserMessagingPlatform.*`, `ConsentDebugSettings`, `ConsentRequestParameters`.
  - ⚠ **iOS: not yet compiled.** No Mac is available; this is verified by the `ios` job in `.github/workflows/ci.yaml` (written in Phase 6; pending its first run). Names used are
    the documented Swift forms: `MobileAds.shared.start()` (async), `requestConfiguration.testDeviceIdentifiers` /
    `.ageRestrictedTreatment`, `InterstitialAd.load(with:request:)` / `RewardedAd.load(with:request:)` (async throws),
    `FullScreenContentDelegate`, `present(from:)`, `present(from:userDidEarnRewardHandler:)`, `adReward`, `BannerView(adSize:)`,
    `BannerViewDelegate`, `AdSizeBanner`/`AdSizeLargeBanner`/`AdSizeMediumRectangle`/`AdSizeLeaderboard`,
    `largeAnchoredAdaptiveBanner(width:)`, `inlineAdaptiveBanner(width:maxHeight:)`, `currentOrientationInlineAdaptiveBanner(width:)`,
    `cgSize(for:)`, and UMP's `ConsentInformation.shared.requestConsentInfoUpdate(with:)`, `ConsentForm.loadAndPresentIfRequired(from:)`,
    `ConsentForm.presentPrivacyOptionsForm(from:)`, `DebugSettings`, `DebugGeography(rawValue:)`.
  - ⚠ **SPM product names:** `GoogleMobileAds` and `GoogleUserMessagingPlatform`, still to be confirmed by the CI build.
  - **RDP:** only `gad_rdp` (SharedPreferences / UserDefaults) is used. Request-extras `rdp` is no longer documented.

### 2.2 Unity Ads (standalone)

| Item | Android | iOS |
|---|---|---|
| Version | 4.21.0 (2026-10-01) | 4.21.0 (2026-10-01) |
| Artifact | `com.unity3d.ads:unity-ads` | SPM `https://github.com/Unity-Technologies/Unity-Ads-Swift-Package` (product `UnityAds`; official, verified 2026-10-12; pod `UnityAds` in 1.0.x) |
| Minimum | Docs say API 19+ (stale text); compileSdk 33+, Kotlin 1.7+. Fine for minSdk 24 | iOS 13 (since 4.16.0); Xcode 26.0.1+ (since 4.18.0) |
| Sources | https://repo1.maven.org/maven2/com/unity3d/ads/unity-ads/maven-metadata.xml · https://docs.unity.com/en-us/grow/ads/changelog | https://github.com/Unity-Technologies/Unity-Ads-Swift-Package/releases |

- **API status (critical):** 4.19.0 **deprecated the entire static API**, with removal scheduled for 5.0.0 (no 5.x on
  Maven Central or the Swift package's releases as of 2026-10-28)
  (https://docs.unity.com/en-us/ads-android/4.20.0/sdk-integration/api/android-deprecated-apis). The adapter uses only:
  - Init: `UnityAds.initialize(InitializationConfiguration.Builder(gameId).withTestMode(b).build(), InitializationListener)`
  - Interstitial / Rewarded: `InterstitialAd.load(LoadConfiguration, LoadListener<InterstitialAd>)`,
    `RewardedAd.load(...)`, then `.show(activity, ShowConfiguration, listener)`. Rewarded has `onRewarded`.
  - Banner: `com.unity3d.ads.BannerAd` + `BannerConfiguration.Builder(placementId, BannerSize, BannerShowListener)`
    (`javap` on the 4.21.0 AAR: `BannerSize` has only `standard`, `iabStandard`, `leaderboard` and `BannerSize(w, h)`;
    no adaptive factory, although the deprecated-APIs page mentions adaptive sizes).
  - Expiry: `InterstitialAd` / `RewardedAd.onAdExpired` (`AdExpiredListener`; iOS `UnityAd.onAdExpired`). Set since
    1.1.0, as Unity's guides require: an expired ad is dropped.
  - ✅ **iOS (checked 2026-10-28 against the 4.21.0 `UnityAds.swiftinterface`):** `UADSInitializationConfigurationBuilder`,
    `UnityAds.initialize(_:completion:)`, `UADSInterstitialAd` / `UADSRewardedAd.load(_:completion:)` +
    `show(_:delegate:)`, `UADS…ShowDelegate.showDidFail(_:error:)` (the Swift API reference's `showDidFailed` doesn't
    exist), `UADSBannerAd.load` + `UADSBannerLoadConfigurationBuilder(placementId:bannerSize:delegate:)` (a fixed
    `CGSize`), `UnityAds.setUserConsent / setUserOptOut / setNonBehavioral`. Not yet compiled in CI.
- **Product status:** **not discontinued**. Unity "will continue to support and provide fill for all apps using
  direct integration" but recommends LevelPlay
  (https://docs.unity.com/en-us/grow/ads/mediation/unity-ads-in-mediation.md).
- **Credentials:** a Game ID **per platform**, plus placement IDs per format.
- **Test mode:** `.withTestMode(true)` on the init configuration (a code flag ✅).
- **Manifest / plist:** none needed on Android (merged from the AAR; AD_ID auto-declared since 4.1). iOS: `SKAdNetworkItems`.
- **SKAdNetwork list:** https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json
- **Privacy (new APIs; "beta" since 4.17; the MetaData keys are removed in 5.0):** `UnityAds.setUserConsent(bool)` (GDPR),
  `UnityAds.setUserOptOut(bool)` (CCPA), `UnityAds.setNonBehavioral(bool)` (COPPA). Source:
  https://docs.unity.com/en-us/monetization/privacy/beta/key-changes.md
- **R8:** the AAR bundles rules. AGP 9 + R8 needs SDK 4.20.0+ (we pin 4.21.0 ✅).
- **iOS:** an app without Swift needs an empty Swift file (Flutter apps already have Swift). Static vs dynamic linkage ⚠.
- ⚠ No RI / App Open format found in the docs. The adapter stubs them.

### 2.3 ironSource / Unity LevelPlay

| Item | Android | iOS |
|---|---|---|
| Version | **9.7.0** (2026-10-22; "general improvements and bug fixes") | **9.7.0** (2026-10-22) |
| Artifact | `com.unity3d.ads-mediation:mediation-sdk` (Maven Central). The legacy `com.ironsource.sdk:mediationsdk` on IS.com has not been served since 2025-06-30 | SPM `https://github.com/ironsource-mobile/LevelPlay-Swift-Package` (9.3.0+; product `UnityMediationSDK`; pod `IronSourceSDK` in 1.0.x) |
| Minimum | API 19+, Kotlin 1.7+ | iOS 12 (9.7.0 `Package.swift` and the integration page); Xcode 16+ (swift-tools 6.0); 9.6.1+ for Xcode 27 |
| Sources | https://repo1.maven.org/maven2/com/unity3d/ads-mediation/mediation-sdk/maven-metadata.xml · https://docs.unity.com/en-us/grow/levelplay/sdk/android/changelog | https://trunk.cocoapods.org/api/v1/pods/IronSourceSDK · https://docs.unity.com/en-us/grow/levelplay/sdk/ios/sdk-integration.md |

- **Rename:** 9.0.0 renamed every public `IronSource.*` API to `LevelPlay.*` and **removed all deprecated APIs**
  (`IronSource.loadInterstitial`, `showRewardedVideo`, `IronSourceBannerLayout` are gone).
- **Current APIs used by the adapter:**
  - Init: `LevelPlay.init(context, LevelPlayInitRequest.Builder(appKey).build(), LevelPlayInitListener)`. On iOS:
    `LevelPlay.initWith(LPMInitRequestBuilder(appKey).build()) { config, error in }`.
  - Ads: `LevelPlayInterstitialAd(adUnitId)`, `LevelPlayRewardedAd(adUnitId)`,
    `LevelPlayBannerAdView(context, adUnitId, config)` with `LevelPlayAdSize.BANNER / LARGE / MEDIUM_RECTANGLE /
    createAdaptiveAdSize(ctx)`. iOS (9.7.0 headers): `LPMAdSize` `bannerSize` / `largeSize` / `mediumRectangleSize` /
    `leaderBoardSize` / `createAdaptiveAdSizeWithWidth:` (Swift `banner()`, `large()`, …, `createAdaptive(withWidth:)`),
    `+[LevelPlay setMetaDataWithKey:value:]` (Swift `setMetaData(withKey:value:)`, as the SDK's own error message
    spells it), `showAdWithViewController:placementName:` (`NS_SWIFT_NAME(showAd(viewController:placementName:))`).
  - **`-ObjC`:** required; LevelPlay's own Swift package comments it out ("should be added manually to the project")
    and the official SPM demo sets it on the app target. Source: https://docs.unity.com/en-us/grow/levelplay/sdk/android/banner-integration.md
- **Credentials:** an App Key plus an ad-unit ID per format.
- **Test mode:** there is no global test-ads flag. Use `LevelPlay.setMetaData("is_test_suite","enable")` and
  `LevelPlay.launchTestSuite(context)`. Test devices are registered in the dashboard ⚠. *`testModeSupport` = test-suite only.*
- **Manifest / plist:** activities and the lifecycle provider are merged from the AAR. API 33+ apps declare `AD_ID`. Add the
  `play-services-appset` and `play-services-ads-identifier` dependencies. iOS `SKAdNetworkItems` (`su67r6k2v3.skadnetwork`),
  optional `NSAdvertisingAttributionReportEndpoint`, and **`NSAllowsArbitraryLoads=YES` (flag for App Store review)**.
- **Privacy** (https://docs.unity.com/en-us/grow/levelplay/sdk/android/regulation-advanced-settings.md):
  `LevelPlayPrivacySettings.setGDPRConsent(bool)` (9.5+; iOS `LPMPrivacySettings`), `setCCPA(bool)`, `setCOPPA(bool)` (9.4+).
  Google UMP / IAB TCF strings are read automatically (7.7.0+).
- **R8:** the docs require a long keep list (`-keep class com.ironsource.adapters.** {*;}`,
  `-keepclassmembers class com.ironsource.** { public *; }`, `-dontwarn com.ironsource.**`, plus the omid and
  JavascriptInterface rules). **The adapter ships these as consumer rules.**
- ⚠ No RI / App Open format in the format index. The adapter stubs them.

### 2.4 AppLovin MAX

| Item | Android | iOS |
|---|---|---|
| Version | 13.6.4 (2026-08-08; still the latest on 2026-10-28) | 13.6.4 (2026-08-08) |
| Artifact | `com.applovin:applovin-sdk` (+ `play-services-ads-identifier`) | SPM `https://github.com/AppLovin/AppLovin-MAX-Swift-Package` (product `AppLovinSDK`; pod `AppLovinSDK` in 1.0.x) |
| Minimum | **minSdk 24** (13.6.3+), Java 8 | iOS 12.0, Xcode 15+ |
| Sources | https://repo1.maven.org/maven2/com/applovin/applovin-sdk/maven-metadata.xml · https://support.applovin.com/en/max/android/overview/integration | https://github.com/AppLovin/AppLovin-MAX-Swift-Package/tags · https://support.applovin.com/en/max/ios/overview/integration |

- **Init (12.4.0+ API):** `AppLovinSdkInitializationConfiguration.builder(sdkKey).setMediationProvider(AppLovinMediationProvider.MAX).build()`
  → `AppLovinSdk.getInstance(ctx).initialize(config) { }`. On iOS: `ALSdkInitializationConfiguration(sdkKey:)` →
  `ALSdk.shared().initialize(with:)`. **The SDK key is passed in code.** Manifest/plist key init is not in the current docs ⚠.
- **Ad classes:** the **context-free** constructors (13.3.0 deprecated every API that takes a `Context` or
  `AppLovinSdk`; AppLovin's format pages still show the old forms): `MaxInterstitialAd(unitId)` + `MaxAdListener`;
  `MaxRewardedAd.getInstance(unitId)` + `MaxRewardedAdListener.onUserRewarded(ad, MaxReward)`; `MaxAdView(unitId, …)`
  + `MaxAdViewAdListener`; `MaxAppOpenAd(unitId)`. On iOS: `MAInterstitialAd`, `MARewardedAd.shared(withAdUnitIdentifier:)`, `MAAdView`.
  Adaptive banners are opt-in via `MaxAdViewConfiguration` / `MAAdViewConfiguration` (13.2.0+; ANCHORED / INLINE,
  `adaptiveWidth`, `inlineMaximumHeight`); the plain banner is a fixed 320×50.
- **RI:** the docs page returns 404 and the format is absent from the iOS nav. **Treated as unsupported** ⚠.
- **Test mode:** `.setTestDeviceAdvertisingIds(listOf(gaid))` on the init builder (Android ✅; the iOS property name is ⚠).
  The Mediation Debugger is also available. *`testModeSupport` = test devices.*
- **Manifest / plist:** none for the key. iOS: `NSUserTrackingUsageDescription` (if the ATT flow is used) and `SKAdNetworkItems` from
  https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json.
- **Privacy:** `AppLovinPrivacySettings.setHasUserConsent(bool)` and `setDoNotSell(bool)` **before init**. Google UMP
  is integrated automatically (12.0+). **`setIsAgeRestrictedUser` was removed in 13.0.0 ("Removed COPPA support").
  The SDK must not be initialized for child users.** The adapter refuses init when `ConsentState.coppa == true`.
- **R8:** bundled in the AAR ✅. **iOS:** binary xcframework through SPM; AppLovin's iOS guide doesn't mention
  `-ObjC` and the adapter doesn't pass it (⚠ add it to the Runner target if you see unrecognized selectors).

### 2.5 Facebook Audience Network (branded Meta Audience Network): **full adapter, bidding-only caveat**

| Item | Android | iOS |
|---|---|---|
| Version | 6.22.0 (Maven, 2026-07-21; still the latest on 2026-10-28; in Meta's changelog) | **6.22.1** (2026-10-20, SPM; rewarded / interstitial fixes) |
| Artifact | `com.facebook.android:audience-network-sdk` | SPM `https://github.com/facebook/FBAudienceNetwork` (6.22.0+, iOS 15; product `FBAudienceNetwork`, confirmed in its `Package.swift`; pod in 1.0.x) |
| Sources | https://repo1.maven.org/maven2/com/facebook/android/audience-network-sdk/maven-metadata.xml · https://developers.facebook.com/docs/audience-network/setting-up/platform-setup/android/changelog | https://cocoapods.org/pods/FBAudienceNetwork · https://github.com/facebook/FBAudienceNetwork |

- **Bidding-only:** Meta Audience Network has been **bidding-only since 2021**. Waterfall placements were removed, so
  a direct `loadAd()` from a standalone integration should expect **no fill in production** (test ads still serve).
  In-house bidding is *"currently in Closed Beta and is not publicly available"*
  (https://developers.secure.facebook.com/docs/audience-network/in-house-mediation). For revenue, the supported route is a
  partner mediation platform: AdMob, AppLovin MAX, ironSource/LevelPlay, Unity and others
  (https://developers.secure.facebook.com/docs/audience-network/guides/partner-mediation).
- **Decision changed (2026-10-07, owner request; A10):** `unified_ads_facebook` was first a documented stub. It is now a
  full direct adapter (banner / interstitial / rewarded) on SDK 6.22.0, so teams can integrate and test Audience Network
  placements. The bidding-only caveat is documented prominently. The abandoned pub.dev plugin `facebook_audience_network`
  (v1.0.1, MIT, Dec 2021) was analysed as a reference only; no code was copied.
- **Verified for the adapter:**
  - Android names: compiler + `javap` on the 6.22.0 AAR. Init via `AudienceNetworkAds.buildInitSettings(ctx).withInitListener{}.initialize()`.
  - Android `AdError` code constants: verified with `javap`.
  - AAR manifest: `minSdkVersion 14` (Meta's changelog says API 21; irrelevant at our minSdk 24).
  - The Android POM pulls `play-services-basement` + `androidx.browser`.
  - iOS: the pod spec declares iOS 15.0; Swift names come from the 6.22.0 headers (⚠ not compiled until CI).
  - iOS `loadAd` has been deprecated since 6.11 ("use loadAdWithBidPayload") but still works for direct loads. The
    Swift names are `load()`, `show(fromRootViewController:)` and `FBAdSettings.isMixedAudience`.
- **Device (CPH1931):** init ✅, banner ✅, interstitial load + show ✅ with `IMG_16_9_APP_INSTALL#` test placements. Rewarded
  load with a non-rewarded placement → native **1203** (display format mismatch, now mapped to `invalidConfig`).
- Distribution change: Meta's iOS changelog says 6.22.x is the **last CocoaPods series** (SPM or zip after that). Moot
  since 1.1.0: the adapter is SPM-only (`Package.swift`, product `FBAudienceNetwork`).
- Other facts: SKAdNetwork IDs `v9wttpbfk9.skadnetwork`, `n38lu8286q.skadnetwork`. Android 9+ needs cleartext to `127.0.0.1`
  (media cache proxy; AdError 7003 otherwise), and the app must declare it (see doc/setup/facebook.md). Privacy:
  `AdSettings.setDataProcessingOptions(["LDU"],0,0)`, `setMixedAudience`. **ATT flag:** Meta requires
  `setAdvertiserTrackingEnabled` on iOS 14.5–16.x; the adapter sets it from the ATT status on iOS 15–16 (1.1.0). On
  iOS 17+ with SDK 6.15+ it is deprecated and not needed.

### 2.6 Start.io (StartApp)

| Item | Android | iOS |
|---|---|---|
| Version | 5.4.0 (2026-10-06) | 4.15.0 (2026-10-05) |
| Artifact | `com.startapp:inapp-sdk` (Maven Central; docs suggest `5.+`, but we pin) | SPM `https://github.com/StartApp-SDK/StartAppSDK-SwiftPackage` (product `StartApp`; official, verified 2026-10-12; pod `StartAppSDK` with vendored `StartApp.xcframework` in 1.0.x) |
| Minimum | API 23 (AAR manifest) | iOS 11 (`Package.swift` 4.15.0; the 1.0.x podspec said 9.0) |
| Sources | https://repo1.maven.org/maven2/com/startapp/inapp-sdk/maven-metadata.xml · https://support.start.io/hc/en-us/articles/360014774799 | https://github.com/StartApp-SDK/StartAppSDK-SwiftPackage · https://support.start.io/hc/en-us/articles/360006012653-IOS-Standard |

- **Credentials:** **one App ID per app. There are no per-format ad-unit IDs.** The format is chosen through `AdMode` or the class.
  *Consequence:* `NetworkConfig.appId` is required, and per-format IDs are optional. If given, they are passed as the
  `adTag` reporting label: Android `AdPreferences.setAdTag`; iOS `STAAdPreferences.adTag` (4.15.0 headers, which also add a
  `placementId` field) for interstitial and rewarded since 1.1.0.
- **Init:** `StartAppSDK.init(context, appId, false)` (the third argument disables return ads), or the manifest meta-data
  `com.startapp.sdk.APPLICATION_ID`. The code-init path (which the adapter uses) requires removing the SDK's auto-init
  provider `com.startapp.sdk.adsbase.StartAppInitProvider` with `tools:node="remove"` — official docs, "Code Initialization"
  (mandatory step 2). The removal must be declared in the CONSUMING APP's manifest: a library-level
  `tools:node="remove"` was not honored by the manifest merger (verified with AGP 9.0.1 — the directive from the
  adapter's library manifest was ignored and the provider survived), so doc/setup/startapp.md lists it as a required
  app-manifest step. On iOS: `[[STAStartAppSDK sharedInstance] initializeWithAppID:completion:]`.
- **Auto-shown ads must be disabled:** splash (on by default on Android → `StartAppAd.disableSplash()`) and return ads
  (on by default → `setReturnAdsEnabled(false)`, the third `init` argument). ⚠ Start.io's docs also document manifest toggles
  `com.startapp.sdk.SPLASH_ENABLED` / `RETURN_ADS_ENABLED`, but string search of the 5.4.0 AAR (classes.jar, assets, libs)
  finds neither key — only `APPLICATION_ID`, `CHILD_DIRECTED`, `MIXED_AUDIENCE` and `CONSENT_ENABLED` are read
  (`com.startapp.sdk.internal.dc`); the code APIs are authoritative on Android. The iOS plist key names are ⚠.
- **Formats:** banner (`Banner`, `Mrec`; iOS `STABannerView`), interstitial (`StartAppAd` + `AdMode`), rewarded
  (`loadAd(AdMode.REWARDED_VIDEO)`; reward callback `VideoListener.onVideoCompleted` ⚠). An interstitial instance
  is single-use. There is no App Open format (only splash).
- **Test mode:** `StartAppSDK.setTestAdsEnabled(true)`; on iOS `testAdsEnabled = YES` (a code flag ✅).
- **Manifest / plist:** the AAR declares INTERNET, ACCESS_WIFI_STATE, ACCESS_NETWORK_STATE, RECEIVE_BOOT_COMPLETED, AD_ID,
  ACCESS_ADSERVICES_TOPICS and the install-referrer permission (no BLUETOOTH), so API 31+ targets are covered. Manifest
  meta-data read by 5.4.0: `APPLICATION_ID`, `CHILD_DIRECTED`, `MIXED_AUDIENCE`, `CONSENT_ENABLED` ⚠ (the last one disables
  Start.io's built-in disclosure dialog). For child-directed apps the official docs additionally require removing the merged
  `ACCESS_WIFI_STATE` permission via `<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" tools:node="remove"/>`
  ("App Permissions (COPPA Compliant)" step). SKAdNetwork IDs:
  https://www.start.io/skadnetworkids.json; Start.io's own is `5l3tpt7t6e.skadnetwork` (entity "Start.io").
  The SDK links AppTrackingTransparency, so `NSUserTrackingUsageDescription` is needed when ATT is requested.
- **Privacy:** GDPR `StartAppSDK.setUserConsent(ctx, "pas", ts, bool)` (iOS `setUserConsent:forConsentType:@"pas"…`).
  CCPA: `getExtras(ctx).edit().putString("IABUSPrivacy_String", …)`. COPPA (Android): meta-data `com.startapp.sdk.CHILD_DIRECTED` /
  `MIXED_AUDIENCE`. COPPA on iOS is ⚠.
- **R8:** the AAR's own rules keep `com.startapp.**` (there is no `com.truenet` rule any more).
- **iOS errors:** `STAError` (0–12 in `STAErrorCodes.h`: 1 NoInternetConnection, 8 AdAlreadyDisplayed, 9 AdExpired,
  10 AdNotReady, 12 NoContent, …), delivered as the `NSError` code; mapped since 1.1.0. The 4.15.0 headers have no
  `NS_SWIFT_NAME`s.
- Reference implementation: the official Flutter plugin `startapp_sdk` (pub.dev).

### 2.7 InMobi

| Item | Android | iOS |
|---|---|---|
| Version | **11.5.1** (2026-10-22, "performance and stability") | 11.5.0 (2026-09-28; still the latest) |
| Artifact | `com.inmobi.monetization:inmobi-ads-kotlin` (the old `inmobi-ads` has been dead since 10.1.4, 2023) | SPM `https://github.com/InMobi/InMobiSDK-Swift-Package` (product `InMobiSDK`; official, verified 2026-10-12; pod `InMobiSDK` in 1.0.x) |
| Minimum | API 21, Kotlin 2.x (11.1.0+), AGP ≥ 8.9.3 | iOS 12 (`Package.swift` and the overview), Xcode 15+ |
| Sources | https://repo1.maven.org/maven2/com/inmobi/monetization/inmobi-ads-kotlin/maven-metadata.xml · https://support.inmobi.com/monetize/sdk-documentation/android-guidelines/overview-android-guidelines | https://trunk.cocoapods.org/api/v1/pods/InMobiSDK · https://support.inmobi.com/monetize/sdk-documentation/ios-guidelines/changelogs |

- **Credentials:** an Account ID (string) plus **numeric (Long) placement IDs** per format. This model is still current ✅.
- **Init:** `InMobiSdk.init(context, accountId, consentJson /* null on 10.7.5+ */, SdkInitializationListener)`
  (UI thread). On iOS: `IMSdk.initWithAccountID(_:consentDictionary:andCompletionHandler:)`.
- **Formats:** `InMobiBanner(ctx, placementId)`, `InMobiInterstitial(ctx, placementId, listener)`. Rewarded is the
  **same `InMobiInterstitial` class with a rewarded placement**, and the reward arrives through
  `onRewardsUnlocked(ad, Map<Any, Any>)`. The adapter maps the first entry to `RewardItem(type, amount)` (key/value
  types ⚠). The iOS reward delegate `interstitial(_:rewardActionCompletedWithRewards: [String: Any])` matches the
  11.5.0 `.swiftinterface` and InMobi's Swift sample. Since 11.4.0 the SDK accepts one account ID per session.
- **Test mode:** **dashboard-only** (per-placement Global/Selective test mode). There is no code flag.
  `InMobiSdk.setLogLevel(DEBUG)` prints the device ID. *`testModeSupport` = none (log-level only). This is documented.*
- **Dependencies:** OkHttp, Okio, media3-exoplayer, kotlinx-coroutines, androidx.browser, Picasso,
  play-services-ads-identifier and location. Whether they arrive transitively through the POM is ⚠.
- **Manifest / plist:** permissions `AD_ID`, `ACCESS_WIFI_STATE`, `ACCESS_FINE_LOCATION` (optional), and
  `hardwareAccelerated="true"`. On iOS: `SKAdNetworkItems` (own ID `wzmmz9fp6w.skadnetwork`; list at
  https://www.inmobi.com/skadnetworkids.json), **`NSAllowsArbitraryLoads=true` (recommended; flag for App Store
  review)**, `NSUserTrackingUsageDescription`, and the linker inputs `-ObjC`, `libsqlite3.0`, `libz`, `WebKit`.
- **Privacy:** TCF/GPP strings are read automatically from any CMP (10.7.5+), so UMP covers it. The legacy consent JSON keys are
  `gdpr_consent_available`, `gdpr_consent`, `gdpr`. COPPA: `InMobiSdk.setIsAgeRestricted(true)`. The CCPA API on Android is ⚠
  (iOS `IMPrivacyCompliance`).
- **R8:** ship `-keep class com.inmobi.** { *; }`, the Picasso, gms and `com.iab` keeps, and
  `-keepattributes SourceFile,LineNumberTable`. Whether the AAR bundles them is ⚠.
- **iOS:** a **dynamic** xcframework since 10.7.2, with a privacy manifest included. 11.5.0 deprecates `IMBanner.cancel()`
  with no replacement (the adapter stops auto-refresh instead). `IMStatusCode` is a `@frozen` Int enum (noFill 1,
  requestTimedOut 4, adActive 8, …). Consent: `IMCommonConstants.IM_GDPR_CONSENT_AVAILABLE` / `IM_SUBJECT_TO_GDPR`.

---

## 3. Cross-cutting findings

### 3.1 Unity Ads vs LevelPlay in one app
The two are separate artifacts, so **there is no duplicate-symbol problem**: LevelPlay mediates Unity through
`com.unity3d.ads-mediation:unityads-adapter`, which resolves to the same `unity-ads` artifact. Unity, however,
**does not support direct and mediated Unity Ads in one process**: *"With different Game IDs, the SDK initializes only
once per process. Whichever integration initializes first wins, and the other fails silently."*
(https://docs.unity.com/en-us/grow/ads/mediation/unity-ads-in-mediation.md)
**Decision:** core performs an init-time guard. If both `unity` and `ironsource` are registered and enabled, it reports
`AdError(configConflict)` and skips `unity`. The docs say: use `unified_ads_unity` only when LevelPlay is not used.

### 3.2 Test-mode capability differs per network
| Network | Mechanism | `testModeSupport` |
|---|---|---|
| AdMob | test device IDs (+ demo unit IDs in the example) | `testDevices` |
| Unity Ads | `withTestMode(true)` | `flag` |
| LevelPlay | test suite / dashboard | `testSuiteOnly` |
| AppLovin MAX | test device GAIDs | `testDevices` |
| Start.io | `setTestAdsEnabled(true)` | `flag` |
| InMobi | dashboard only | `none` |
| Facebook Audience Network | `AdSettings.addTestDevices` (hashed IDs) or `IMG_16_9_APP_INSTALL#` placements | `testDevices` |

`AdConfig.testMode` is therefore **best effort per network** and is documented as such. Core logs a warning at init for
networks whose `testModeSupport` cannot force test ads.

### 3.3 Consent propagation
UMP writes the IAB TCF v2 / GPP strings, which InMobi (10.7.5+), MAX (12.0+) and LevelPlay (7.7+) read automatically. Unity
and Start.io need explicit setters, which are called from each adapter's `applyConsent(ConsentState)`. MAX has a hard COPPA
restriction (see §2.4).

### 3.4 Toolchain compatibility (Flutter 3.44.6 template: AGP 9.0.1, Kotlin 2.3.20, compileSdk 36)
| Constraint | Source | Status |
|---|---|---|
| minSdk 24 | GMA Next-Gen, MAX 13.6.3+ | ✅ the template already uses 24 |
| Kotlin ≥ 2.1 | AdMob 24.1+, InMobi 11.1+ | ✅ 2.3.20 |
| compileSdk ≥ 35 | AdMob | ✅ 36 |
| AGP 9 + R8 | Unity Ads needs 4.20.0+ | ✅ pinned 4.21.0 |
| Xcode ≥ 26.2 ⚠ | AdMob iOS 13.4+ | CI must use a macOS runner with Xcode 26.2+ |

### 3.5 Unverified API names (must be verified in Phase 3/4 before coding)
- AdMob: the individual iOS v12 Swift class names, the iOS missing-App-ID behaviour, static vs dynamic xcframework, and the Xcode floor (16.0 vs 26.2).
- Unity Ads: **the iOS names for the 4.19 instance APIs**, the SPM URL, and the absence of RI/App Open.
- LevelPlay: the test-device mechanism and the absence of RI/App Open.
- AppLovin MAX: the iOS test-device builder property, and whether manifest-key init still exists.
- Start.io: `VideoListener` / `AdMode` values, the `adTag`, the iOS splash/return-ad plist keys, iOS COPPA, and the Android minSdk.
- InMobi: the iOS reward delegate, the reward-map types, the Android CCPA API, whether consumer rules are bundled, and the iOS minimum.
- Facebook Audience Network: ✅ resolved during the 2026-10-07 upgrade (Android javap/compiler; iOS headers, ⚠ until CI).

### 3.6 Implementation check (Phase 4, 2026-10-07)
Phase 4 re-verified every adapter's API names against the docs **and the shipped binaries** (`javap` on the AARs; iOS
headers / `.swiftinterface` for MAX, LevelPlay, Start.io and InMobi). The Android code of all six native adapters then
**compiled against the pinned SDKs**. Corrections the compiler or binaries forced:

| Network | Correction |
|---|---|
| AppLovin MAX | `MaxAdViewConfiguration` lives in `com.applovin.mediation` (not `…mediation.ads`). The Context-taking constructors are deprecated (13.3), so only context-free APIs are used. |
| Unity Ads | The privacy APIs are Kotlin **properties** (`UnityAds.userConsent / userOptOut / nonBehavioral`), not `set…()` functions as the docs show. |
| LevelPlay | Banner size and placement are set **only** through `LevelPlayBannerAdView.Config.Builder`. The banner's `onAdDisplayFailed(adInfo, error)` argument order is reversed. |
| InMobi | Banners must be sized through `layoutParams` before `load()` (`setBannerSize` is deprecated). The init callback receives `java.lang.Error?`. |
| Start.io | The iOS splash / return-ad switches are deprecated no-ops (4.15). Android uses `initParams(...).setReturnAdsEnabled(false)` + `disableSplash()`. |

Each `doc/setup/<network>.md` lists the API names used, split into ✅ compiler-verified (Android) and ⚠ not yet compiled (iOS, Phase 6 CI).

### 3.7 Platform changes found while documenting credentials (2026-10-07)
- **ironSource Ads direct demand sunset:** no new publishers from 15 April 2026, direct demand stopped on **30 April 2026**,
  and the dashboard is read-only (https://unity.com/products/ironsource-ads-sunset). **LevelPlay mediation continues.** Fill
  comes from networks enabled in LevelPlay (Unity recommends Unity Ads bidding). This explains the "no available ad" result
  for the LevelPlay demo key on the device in Phase 4. The `unified_ads_ironsource` adapter is unaffected; apps must enable
  demand networks (and add their LevelPlay adapters).
- **Unity Ads waterfall placements phased out:** the migration deadline was 11 August 2026, and new placements are bidding-only
  (https://docs.unity.com/en-us/grow/dashboard/ad-units). The direct `unified_ads_unity` integration served on a device with
  Unity's sample game (legacy placements). ⚠ Serving from bidding-only placements in a new project still needs
  confirming with a real Game ID.
- Credential how-tos for every network, with official links: `doc/getting_ids.md`.

### 3.8 Re-verification against the vendors' current guides (2026-10-28, 1.1.0)
Every network's Android and iOS integration guide, Maven metadata and Swift package releases were re-read. The iOS
binaries were downloaded and their `.swiftinterface` / headers read: UnityAds 4.21.0, LevelPlay 9.7.0, InMobiSDK
11.5.0, StartApp 4.15.0 and FBAudienceNetwork 6.22.1. All Android changes were compiled (example APK) and the Kotlin
tests and Android opt-in checks re-run. iOS still compiles only in CI.

| Network | Pin change | Code change | Doc fixes |
|---|---|---|---|
| AdMob | Next-Gen 1.5.0 → **1.6.0** (Android) | `bannerAdRefreshCallback` re-reports the size after a refresh | §2.1 described the legacy SDK |
| AppLovin MAX | none (13.6.4 latest) | none | context-free APIs; adaptive banners are opt-in, not the default |
| Unity Ads | none (4.21.0 latest; 5.x not shipped) | **`onAdExpired`** handled on both platforms | iOS names confirmed (`showDidFail`); no adaptive `BannerSize`; Xcode 26.0.1+ |
| LevelPlay | 9.6.1 → **9.7.0** (both) | **iOS `setMetaData(withKey:value:)`** (the old `setMetaDataWithKey(_:value:)` call doesn't compile); iOS adaptive banner passes the width | iOS min 12; `-ObjC` on the Runner target is required; "Mediation → Setup → SDK Networks" |
| InMobi | Android 11.5.0 → **11.5.1** | iOS links **`libz`** (required); `cancel()` (deprecated) replaced; iOS consent sent at init with `IM_SUBJECT_TO_GDPR`, as on Android | iOS 12; ATS recommendation; SKAdNetwork source |
| Start.io | none | iOS ad tag (`STAAdPreferences.adTag`) for full-screen ads; iOS `STAError` mapping | Android 23 / iOS 11; own SKAdNetwork ID `5l3tpt7t6e` (now enforced by `tool/verify_ios_plist.dart`) |
| Facebook | iOS 6.22.0 → **6.22.1** | **`setAdvertiserTrackingEnabled` on iOS 15–16** (also forwarded by the AdMob / MAX / LevelPlay Meta-bidding path) | `loadAd` deprecated since 6.11; Swift names; new SKAdNetwork URL |
| Meta bidding adapters | LevelPlay 5.5.0 → **5.6.0** (brings FAN on Android), AppLovin Swift package → **6220100.0.0** | — | iOS FAN pins differ: Google 6.22.0, AppLovin / LevelPlay 6.22.1 (§1.1) |

Still ⚠ until a CI compile: LevelPlay `large()` / `leaderBoard()` / `createAdaptive(withWidth:)` (importer-derived from the
9.7.0 headers), Start.io `initialize(withAppID:completion:)` (importer-derived), the unit of Start.io's iOS consent
timestamp, where MAX's dashboard creates App Open units, and InMobi's dashboard test-mode labels.
