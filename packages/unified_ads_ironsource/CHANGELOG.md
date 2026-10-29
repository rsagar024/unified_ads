## 1.1.0

* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* iOS SDK comes from `LevelPlay-Swift-Package` (`UnityMediationSDK`; 9.7.0, see below). `Package.swift` passes
  `-ObjC` to the linker (⚠ to be confirmed by CI); also add `-ObjC` to the Runner target's Other Linker Flags, as
  LevelPlay requires.
* Android: `com.google.android.gms:play-services-appset` 16.0.0 → 16.1.0 and
  `com.google.android.gms:play-services-ads-identifier` 18.1.0 → 18.3.0.
* Opt-in linking on iOS now works through SPM: the vendor SDK is declared only in this package's `Package.swift`,
  so `FlutterGeneratedPluginSwiftPackage` resolves it only when the app depends on this package (checked against
  `Package.resolved` in CI).
* Meta (Facebook) bidding on iOS is now added as a Swift package to the Runner target instead of a pod line; see
  the setup doc and the migration guide.
* Pigeon bindings regenerated with pigeon ^29.0.8.
* LevelPlay 9.6.1 → **9.7.0** on Android and iOS (vendor: general improvements and bug fixes).
* **iOS fix:** the Meta mixed-audience metadata call is now `LevelPlay.setMetaData(withKey:value:)`, the Swift name of
  `+setMetaDataWithKey:value:` in the 9.7.0 headers (the previous spelling didn't compile).
* iOS: adaptive banners now pass the requested width (`createAdaptive(withWidth:)`), as on Android.
* iOS: with an opt-in Meta bidding adapter, `FBAdSettings.setAdvertiserTrackingEnabled` is set on iOS 15–16.
* Docs: `-ObjC` on the Runner target is required; Meta adapter `facebook-adapter` 5.6.0 (brings Audience Network on
  Android) and Swift package 5.6.0; dashboard path "Mediation → Setup → SDK Networks".
* README: package-specific.
* No Dart API changes.

## 1.0.0

Initial release: the ironSource / Unity LevelPlay adapter for `unified_ads`.

* Banner, interstitial and rewarded ads behind the unified `AdNetworkAdapter` contract (Pigeon + Kotlin + Swift).
* Pinned SDKs: Android `com.unity3d.ads-mediation:mediation-sdk` 9.6.1; iOS `IronSourceSDK` 9.6.1.0 (CocoaPods and Swift Package Manager).
* Adding this package links only this network's SDK. Apps without it never pull it in, which CI verifies.
* Uses the LevelPlay 9.x `LevelPlay*` ad-unit APIs. Ads load only after init completes.
* A late reward callback (after close) is still delivered.
* **Meta (Facebook) bidding, opt-in.** Add the vendor's Meta adapter to your app (Gradle, CocoaPods or Swift Package Manager). The adapter detects it, logs it at init, and forwards CCPA opt-out (Limited Data Use) and COPPA (mixed audience) to Audience Network before mediation starts. This package declares no Meta dependency. See the setup doc.
  `Meta_Mixed_Audience` metadata is also set for COPPA. LevelPlay's Android Meta adapter doesn't bring Audience
  Network, so the app adds it.
* Every native error maps to an `AdError` with the SDK's own code in `nativeCode`.

Known limitations:

* Test mode is the LevelPlay test suite only; `testMode` cannot force test ads.
* Runtime-exclusive with `unified_ads_unity`: when both are enabled, `unity` is skipped with `configConflict`.
* iOS sources compile only in CI (`flutter build ios --no-codesign`) and have not yet run on a device.
