## 1.0.0

Initial release: the InMobi adapter for `unified_ads`.

* Banner, interstitial and rewarded ads behind the unified `AdNetworkAdapter` contract (Pigeon + Kotlin + Swift).
* Pinned SDKs: Android `com.inmobi.monetization:inmobi-ads-kotlin` 11.5.0; iOS `InMobiSDK` 11.5.0 (CocoaPods).
* Adding this package links only this network's SDK. Apps without it never pull it in, which CI verifies.
* The Account ID goes in `NetworkConfig.appId`. Placement IDs are numeric.
* The reward is read from the InMobi rewards map.
* Every native error maps to an `AdError` with the SDK's own code in `nativeCode`.

Known limitations:

* Test mode can only be enabled in the InMobi dashboard; `testMode` cannot force test ads (an init-time warning says so).
* iOS sources compile only in CI (`flutter build ios --no-codesign`) and have not yet run on a device.
