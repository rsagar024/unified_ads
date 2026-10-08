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
