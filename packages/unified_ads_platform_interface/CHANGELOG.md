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
