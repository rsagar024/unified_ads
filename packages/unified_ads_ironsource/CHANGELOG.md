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
