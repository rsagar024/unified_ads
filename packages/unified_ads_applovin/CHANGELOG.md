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
