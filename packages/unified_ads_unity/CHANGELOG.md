## 1.1.0

* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* New `Package.swift`: the iOS SDK now comes from Unity's official Swift package
  `https://github.com/Unity-Technologies/Unity-Ads-Swift-Package` 4.21.0 (`UnityAds`); version unchanged.
* Opt-in linking on iOS now works through SPM: the vendor SDK is declared only in this package's `Package.swift`,
  so `FlutterGeneratedPluginSwiftPackage` resolves it only when the app depends on this package (checked against
  `Package.resolved` in CI).
* Pigeon bindings regenerated with pigeon ^29.0.8.
* Expired ads are now handled on both platforms (`onAdExpired`, as Unity's guides require): an expired interstitial /
  rewarded ad is dropped, so `show()` reports `notReady` and the core cache loads a fresh one.
* iOS names re-checked against the UnityAds 4.21.0 `.swiftinterface` (`showDidFail(_:error:)` etc.); comments and docs
  corrected (4.21.0 has no adaptive banner size; Xcode 26.0.1+). SDK 4.21.0 is still the latest.
* README: package-specific.
* No Dart API changes.

## 1.0.0

Initial release: the Unity Ads adapter for `unified_ads`.

* Banner, interstitial and rewarded ads behind the unified `AdNetworkAdapter` contract (Pigeon + Kotlin + Swift).
* Pinned SDKs: Android `com.unity3d.ads:unity-ads` 4.21.0; iOS `UnityAds` 4.21.0 (CocoaPods).
* Adding this package links only this network's SDK. Apps without it never pull it in, which CI verifies.
* Built only on the 4.19+ instance APIs, because the static API is removed in Unity Ads 5.0.
* The reward amount and type come from `NetworkConfig.extras`.
* Every native error maps to an `AdError` with the SDK's own code in `nativeCode`.

Known limitations:

* Runtime-exclusive with `unified_ads_ironsource` (LevelPlay): when both are enabled, `unity` is skipped with `configConflict`.
* iOS sources compile only in CI (`flutter build ios --no-codesign`) and have not yet run on a device.
