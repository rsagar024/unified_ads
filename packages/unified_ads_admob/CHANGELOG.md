## 1.1.0

* README restyled (✨ Features, 🚀 Getting Started, 📖 Usage, …), with usage for interstitial pacing and ad-free mode
  (`AdPacing`, `UnifiedAds.recordAction`, `UnifiedAds.setAdFree`, all from `unified_ads` 1.1.0). No adapter code
  changes.
* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* iOS SDKs come from `swift-package-manager-google-mobile-ads` 13.11.0 (`GoogleMobileAds`) and
  `swift-package-manager-google-user-messaging-platform` 3.1.0 (`GoogleUserMessagingPlatform`); versions unchanged.
* Opt-in linking on iOS now works through SPM: the vendor SDK is declared only in this package's `Package.swift`,
  so `FlutterGeneratedPluginSwiftPackage` resolves it only when the app depends on this package (checked against
  `Package.resolved` in CI).
* Meta (Facebook) bidding on iOS is now added as a Swift package to the Runner target instead of a pod line; see
  the setup doc and the migration guide.
* Pigeon bindings regenerated with pigeon ^29.0.8.
* Android: GMA Next-Gen `ads-mobile-sdk` 1.5.0 → **1.6.0** (no breaking changes; fixes `onUserEarnedReward` arriving
  after `onAdDismissedFullScreenContent`, the Activity context for mediated full-screen ads, and an R8 full-mode crash).
* Android: banners set `bannerAdRefreshCallback`, so an inline-adaptive banner that changes height on refresh is
  re-sized in Flutter (`BannerSized`).
* iOS: with an opt-in Meta bidding adapter, `FBAdSettings.setAdvertiserTrackingEnabled` is now set from the ATT status
  on iOS 15–16 (Meta requires it below iOS 17), through the Objective-C runtime as before.
* README: package-specific, with setup, IDs, consent and error mapping; docs re-verified against Google's guides.
* No Dart API changes.

## 1.0.0

Initial release: the Google AdMob adapter for `unified_ads`.

* Banner, interstitial and rewarded ads behind the unified `AdNetworkAdapter` contract (Pigeon + Kotlin + Swift).
* Rewarded interstitial and app open, on both platforms.
* Pinned SDKs: Android **GMA Next-Gen** `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk` 1.5.0 +
  `user-messaging-platform` 4.0.0 (it replaced the legacy `play-services-ads` before release; see
  `doc/migration/1.0.0-admob-next-gen.md`); iOS `Google-Mobile-Ads-SDK` 13.11.0 + `GoogleUserMessagingPlatform` 3.1.0 (CocoaPods and Swift Package Manager).
* Adding this package links only this network's SDK. Apps without it never pull it in, which CI verifies.
* `AdmobConsentProvider`: a Google UMP implementation of `ConsentProvider` (consent form, privacy options, `canRequestAds`, debug geography).
* Adaptive, standard and inline banners.
* Test mode uses `NetworkConfig.testDeviceIds`.
* **Meta (Facebook) bidding, opt-in.** Add the vendor's Meta adapter to your app (Gradle, CocoaPods or Swift Package Manager). The adapter detects it, logs it at init, and forwards CCPA opt-out (Limited Data Use) and COPPA (mixed audience) to Audience Network before mediation starts. This package declares no Meta dependency. See the setup doc.
* Every native error maps to an `AdError` with the SDK's own code in `nativeCode`.

Known limitations:

* The App ID must also be declared in `AndroidManifest.xml` and `Info.plist`, because the SDK reads it at startup.
* GMA Next-Gen can't coexist with the legacy `play-services-ads` (for example, the official `google_mobile_ads` plugin).
  Apps whose other dependencies pull it must exclude it; the migration note has the Gradle snippet.
* iOS sources compile only in CI (`flutter build ios --no-codesign`) and have not yet run on a device.
