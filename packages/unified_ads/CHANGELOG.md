## 1.1.0

* **New: interstitial pacing.** `AdConfig.pacing` takes an `AdPacing` per full-screen format: `minInterval`
  (cooldown between shows), `showEveryActions` (show after every N `UnifiedAds.recordAction()` calls) and
  `initialDelay` (no show right after the first init). It works alongside `FrequencyCap`, and `show()` fails with
  `frequencyCapped`, naming the rule, without contacting the network. Also available as `pacing` in
  `pubspec.yaml` / `ads_config.json` (`minIntervalSeconds`, `showEveryActions`, `initialDelaySeconds`).
* **New: ad-free mode for Pro users.** `UnifiedAds.setAdFree(bool, {blockRewarded})`, `isAdFree`, `isBlocked(format)` and
  `adFreeChanges`. Banners collapse (and reload when ads come back), interstitial / app open `load()` / `show()` /
  `preload()` return the new `AdErrorCode.adsBlocked`, and cached ads of blocked formats are released. Rewarded formats
  stay available unless `blockRewarded` is set.
* New `UnifiedAds.recordAction()` / `actionCount`, and `FullScreenAd.canShow()` (ready + not blocked + cap and pacing
  met, without side effects).
* `FrequencyStore` gains `readActionCount` / `writeActionCount` / `readActionMark` / `writeActionMark` with default
  bodies, so a persistent store can keep the action count across launches.
* **Migration note:** an exhaustive `switch` over `AdErrorCode` needs a case for `adsBlocked`, and a store declared with
  `implements FrequencyStore` must add the four new methods (`extends` keeps compiling). See the README's
  "Migration notes".
* README restyled (✨ Features, 📖 Quick start, …), with a new "Pacing, frequency caps and ad-free" section.
* **BREAKING (iOS):** CocoaPods support is removed; iOS builds use **Swift Package Manager only** (the podspec is
  deleted). Requires Flutter >= 3.44 with SPM enabled and Xcode 26.2+. The deployment target is now set on the Runner
  target in Xcode. See the [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* The iOS ATT helper still weak-links `AppTrackingTransparency` (now via a `-weak_framework` linker flag in
  `Package.swift`, ⚠ to be confirmed by CI), so the plugin still loads on iOS 13.
* The iOS privacy manifest (`PrivacyInfo.xcprivacy`) is bundled as an SPM resource.
* Constraints on the other unified_ads packages are now `^1.1.0`.
* **Fix:** `show()` on a full-screen ad no longer waits forever when the network's SDK sends neither a
  "shown" nor a "failed to show" callback (seen with Unity Ads and AppLovin MAX on the iOS simulator).
  It now fails with `AdErrorCode.timeout` after the new `AdConfig.showTimeout` (default 15 s;
  `showTimeoutMs` in `ads_config.json`). Additive, non-breaking.
* `FakeAdNetworkAdapter.showDelay` (testing).
* README: the complete guide (configuration, API, getting IDs for every network, platform setup, consent and ATT,
  architecture, SDK status), re-verified against every vendor's current Android and iOS guide.

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
