## 1.1.0

* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* The iOS ATT helper still weak-links `AppTrackingTransparency` (now via a `-weak_framework` linker flag in
  `Package.swift`, ⚠ to be confirmed by CI), so the plugin still loads on iOS 13.
* The iOS privacy manifest (`PrivacyInfo.xcprivacy`) is bundled as an SPM resource.
* Constraints on the other unified_ads packages are now `^1.1.0`.
* No Dart API changes.

## 1.0.0

Initial release.

* `UnifiedAds` facade:
  * `init` / `isInitialized` / `dispose`, safe on re-init and hot restart;
  * a broadcast `events` stream;
  * a pluggable `logger`, silent by default.
* `RewardedInterstitialAd` (with `RewardedInterstitialCallback`) and `AppOpenAd`, behind the same waterfall, cache,
  frequency caps and callbacks. Networks without the format are skipped (today: AdMob has both, AppLovin MAX has app
  open).
* `InterstitialAd` and `RewardedAd`: `load()` / `show()` / `isReady`, every callback, and `servedBy` (the network that
  served the ad).
* `BannerAd` + `UnifiedBannerWidget`:
  * platform-view banners in standard, adaptive and inline sizes;
  * anchored or inline placement;
  * `forceNetwork` and collapse-on-failure.
* Waterfall across networks with per-network timeouts and automatic fallback. The preload cache refills after close.
  Frequency capping per format.
* Declarative config:
  * `AdConfigLoader` (`ads_config.json`, per-platform IDs, errors with a JSON path);
  * `dart run unified_ads:generate_config` turns a pubspec `unified_ads:` section into that asset, with
    `--set-exit-if-changed` for CI.
* Consent and ATT:
  * `gatherConsent` / `updateConsent` with any `ConsentProvider`;
  * `requestTrackingAuthorization` / `trackingAuthorizationStatus` (the iOS ATT helper; weak-linked).
* `package:unified_ads/testing.dart`: a scriptable `FakeAdNetworkAdapter` for app tests.
* The app never crashes because of an ad: every failure is an `AdError` / `AdResult`.
