## 1.0.0

Initial release: the Start.io (formerly StartApp) adapter for `unified_ads`.

* Banner, interstitial and rewarded ads behind the unified `AdNetworkAdapter` contract (Pigeon + Kotlin + Swift).
* Pinned SDKs: Android `com.startapp:inapp-sdk` 5.4.0; iOS `StartAppSDK` 4.15.0 (CocoaPods).
* Adding this package links only this network's SDK. Apps without it never pull it in, which CI verifies.
* Needs only the App ID. Ad-unit IDs are optional ad tags (`requiresAdUnitId` is false).
* Splash and return ads are disabled by the adapter.
* Every native error maps to an `AdError` with the SDK's own code in `nativeCode`.

Known limitations:

* COPPA is manifest-only on Android, and there is no documented iOS COPPA API.
* iOS sources compile only in CI (`flutter build ios --no-codesign`) and have not yet run on a device.
