## 1.1.0

* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* iOS SDK comes from `github.com/facebook/FBAudienceNetwork` (`FBAudienceNetwork`, **iOS 15+**); see the 6.22.1 bump
  below.
* Opt-in linking on iOS now works through SPM: the vendor SDK is declared only in this package's `Package.swift`,
  so `FlutterGeneratedPluginSwiftPackage` resolves it only when the app depends on this package (checked against
  `Package.resolved` in CI).
* Pigeon bindings regenerated with pigeon ^29.0.8.
* iOS: FBAudienceNetwork 6.22.0 → **6.22.1** (rewarded / interstitial fixes). It now matches AppLovin's (`6220100.0.0`)
  and LevelPlay's (`5.6.0`) Meta Swift packages; Google's Meta package still pins 6.22.0, so it can't share an iOS app
  with this version. Android stays on 6.22.0, the latest on Maven.
* iOS: `FBAdSettings.setAdvertiserTrackingEnabled` is now set from the ATT status on iOS 15–16, as Meta requires below
  iOS 17 (at consent time and before init). iOS 17+ is unchanged.
* Docs: `loadAd` deprecated since 6.11; Swift names `load()` / `show(fromRootViewController:)` / `isMixedAudience`.
* README: package-specific.
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
