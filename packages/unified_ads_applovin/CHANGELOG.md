## 1.1.0

* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* iOS SDK comes from `AppLovin-MAX-Swift-Package` 13.6.4 (`AppLovinSDK`); version unchanged.
* Opt-in linking on iOS now works through SPM: the vendor SDK is declared only in this package's `Package.swift`,
  so `FlutterGeneratedPluginSwiftPackage` resolves it only when the app depends on this package (checked against
  `Package.resolved` in CI).
* Meta (Facebook) bidding on iOS is now added as a Swift package to the Runner target instead of a pod line; see
  the setup doc and the migration guide.
* Pigeon bindings regenerated with pigeon ^29.0.8.
* No Dart API changes.

## 1.0.0

Initial release: the AppLovin MAX adapter for `unified_ads`.

* Banner, interstitial and rewarded ads behind the unified `AdNetworkAdapter` contract (Pigeon + Kotlin + Swift).
* Pinned SDKs: Android `com.applovin:applovin-sdk` 13.6.4; iOS `AppLovinSDK` 13.6.4 (CocoaPods and Swift Package Manager).
* Adding this package links only this network's SDK. Apps without it never pull it in, which CI verifies.
* The SDK key is passed in code (`NetworkConfig.appId`).
* The revenue-paid callback is reported as `onImpression`.
* Test mode uses `NetworkConfig.testDeviceIds`.
* App open ads (`MaxAppOpenAd` / `MAAppOpenAd`).
* **Meta (Facebook) bidding, opt-in.** Add the vendor's Meta adapter to your app (Gradle, CocoaPods or Swift Package Manager). The adapter detects it, logs it at init, and forwards CCPA opt-out (Limited Data Use) and COPPA (mixed audience) to Audience Network before mediation starts. This package declares no Meta dependency. See the setup doc.
* Every native error maps to an `AdError` with the SDK's own code in `nativeCode`.

Known limitations:

* MAX dropped COPPA support in 13.0, so unified_ads skips MAX when `ConsentState.coppa` is true.
* With an invalid SDK key, MAX reports init success but never calls back, so loads end with `AdErrorCode.timeout`.
* iOS sources compile only in CI (`flutter build ios --no-codesign`) and have not yet run on a device.
