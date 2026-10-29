## 1.1.0

* New `AdPacing` model and `AdConfig.pacing` (cooldown, show every N actions, initial delay per full-screen format).
* New `AdErrorCode.adsBlocked`, returned while ads are switched off with `UnifiedAds.setAdFree`. **Migration note:**
  an exhaustive `switch` over `AdErrorCode` needs a new case.
* **BREAKING (iOS, ecosystem):** released together with the other unified_ads packages, which are now
  **Swift Package Manager only** on iOS (CocoaPods support removed). This package has no native code. See the
  [migration guide](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.1.0-swift-package-manager.md).
* New `AdConfig.showTimeout` (default 15 s): how long a full-screen `show()` may wait for the SDK to
  report "shown" or "failed to show". Additive, non-breaking.
* README: package-specific guide for adapter authors, including the full `AdNetworkAdapter` contract.

## 1.0.0

Initial release.

* `AdNetworkAdapter` contract and `AdapterRegistry`. Adapters register themselves from their `dartPluginClass`.
* `BridgedAdNetworkAdapter`: a base class for Pigeon/method-channel adapters. It never throws, maps
  `PlatformException` → `AdError`, tracks loaded ads, and translates native events.
* `BridgedAdNetworkAdapter.logMetaBidding`: a protected helper the mediation adapters use to report the opt-in Meta
  bidding adapter.
* Shared models: `AdNetwork`, `AdFormat`, `AdConfig`, `NetworkConfig`, `PlatformValue`, `AdError` / `AdErrorCode`,
  `AdResult`, the sealed `AdEvent` hierarchy, `BannerSize`, `BannerRequest`, `RewardItem`, `FrequencyCap`,
  `PreloadPolicy`, `TestModeSupport`.
* `ConsentState` / `ConsentProvider`, `TrackingStatus` / `TrackingAuthorization`.
* `AdsLogger` with levels and pluggable sinks, silent by default.
* `UnsupportedAdNetworkAdapter` for documented stubs.
