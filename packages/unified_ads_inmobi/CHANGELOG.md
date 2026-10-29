## 1.1.0

* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* New `Package.swift`: the iOS SDK now comes from InMobi's official Swift package
  `https://github.com/InMobi/InMobiSDK-Swift-Package` 11.5.0 (`InMobiSDK`); version unchanged. It passes `-ObjC`
  to the linker (⚠ to be confirmed by CI; fallback: add `-ObjC` to the Runner target's Other Linker Flags).
* Opt-in linking on iOS now works through SPM: the vendor SDK is declared only in this package's `Package.swift`,
  so `FlutterGeneratedPluginSwiftPackage` resolves it only when the app depends on this package (checked against
  `Package.resolved` in CI).
* Pigeon bindings regenerated with pigeon ^29.0.8.
* Android: `inmobi-ads-kotlin` 11.5.0 → **11.5.1** (vendor: performance and stability).
* iOS: the manifest now links `libz`, which InMobi lists as required (with `libsqlite3.0`, `WebKit` and `-ObjC`).
* iOS: banners no longer call the deprecated `IMBanner.cancel()` (11.5.0); auto-refresh is stopped instead.
* iOS: consent now matches Android: `gdprApplies` is sent (`IM_SUBJECT_TO_GDPR`), signals known before init go into
  `initWithAccountID(_:consentDictionary:andCompletionHandler:)`, and `updateGDPRConsent` is called only after init.
* README: package-specific.
* No Dart API changes.

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
