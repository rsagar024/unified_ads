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
