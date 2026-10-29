## 1.1.0

* Docs (Android, verified against Start.io's current integration guide and the 5.4.0 AAR): the **required** app-manifest
  removal of the SDK's auto-init provider `StartAppInitProvider` ("Code Initialization" path — the adapter inits in code),
  the COPPA step that removes the merged `ACCESS_WIFI_STATE` permission via `tools:node`, and the optional
  `com.startapp.sdk.CONSENT_ENABLED` meta-data are now documented (`doc/setup/startapp.md`, README); the example app
  declares the required removal. Library-level `tools:node="remove"` is not honored by the manifest merger (verified with
  AGP 9.0.1), which is why the step belongs in the app manifest. Also corrected: SDK 5.4.0 reads only `APPLICATION_ID`,
  `CHILD_DIRECTED`, `MIXED_AUDIENCE` and `CONSENT_ENABLED` — the `SPLASH_ENABLED` / `RETURN_ADS_ENABLED` manifest toggles
  in Start.io's docs are not read by this version (the adapter disables both in code).
* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* New `Package.swift`: the iOS SDK now comes from Start.io's official Swift package
  `https://github.com/StartApp-SDK/StartAppSDK-SwiftPackage` 4.15.0 (`StartApp`); version unchanged.
* Opt-in linking on iOS now works through SPM: the vendor SDK is declared only in this package's `Package.swift`,
  so `FlutterGeneratedPluginSwiftPackage` resolves it only when the app depends on this package (checked against
  `Package.resolved` in CI).
* Pigeon bindings regenerated with pigeon ^29.0.8.
* iOS: the per-format value is now sent as the ad tag (`STAAdPreferences.adTag`) for interstitial and rewarded ads, as on
  Android.
* iOS: `STAError` codes are mapped (no internet → `networkError`, invalid params → `invalidConfig`, already displayed →
  `alreadyShowing`, expired / not ready → `notReady`, …) instead of reporting every load failure as `noFill`.
* Docs: Start.io's SKAdNetwork ID `5l3tpt7t6e.skadnetwork` (now enforced by `tool/verify_ios_plist.dart`); minimums
  Android 23 / iOS 11.
* README: package-specific.
* No Dart API changes.

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
