## 1.1.0

* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* iOS SDK comes from `github.com/facebook/FBAudienceNetwork` 6.22.0 (`FBAudienceNetwork`, **iOS 15+**); version
  unchanged.
* Opt-in linking on iOS now works through SPM: the vendor SDK is declared only in this package's `Package.swift`,
  so `FlutterGeneratedPluginSwiftPackage` resolves it only when the app depends on this package (checked against
  `Package.resolved` in CI).
* Pigeon bindings regenerated with pigeon ^29.0.8.
* No Dart API changes.

## 1.0.0

Initial release: the Facebook Audience Network (branded Meta Audience Network) adapter for `unified_ads`.

* Banner, interstitial and rewarded ads behind the unified `AdNetworkAdapter` contract (Pigeon + Kotlin + Swift).
* Pinned SDKs:
  * Android: `com.facebook.android:audience-network-sdk` 6.22.0
  * iOS: `FBAudienceNetwork` 6.22.0 (**iOS 15+**; CocoaPods and Swift Package Manager)
* Adding this package links only the Audience Network SDK. Apps without it never pull it in, which CI verifies.
* Test mode uses `NetworkConfig.testDeviceIds`.
* Consent: a CCPA opt-out maps to Limited Data Use, and COPPA maps to mixed audience.
* Every native error maps to an `AdError` with the SDK's own code in `nativeCode`.
* Renamed from `unified_ads_meta` / `MetaAdapter` / `AdNetwork.meta` before the first release
  (see `doc/migration/1.0.0-meta-to-facebook.md`).

* For production Meta demand, use opt-in bidding through `unified_ads_admob`, `unified_ads_applovin` or
  `unified_ads_ironsource` instead (see `doc/setup/facebook.md`).

Known limitations:

* Audience Network is **bidding-only**. Direct loads serve test ads, but production fill needs mediation bidding.
* Android apps must allow cleartext traffic to `127.0.0.1`; otherwise the SDK fails with error 7003.
* iOS sources compile only in CI (`flutter build ios --no-codesign`) and have not yet run on a device.
