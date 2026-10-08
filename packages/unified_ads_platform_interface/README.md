# unified_ads_platform_interface

The common platform interface for [`unified_ads`](https://pub.dev/packages/unified_ads). It contains:

- the `AdNetworkAdapter` contract that every network adapter implements;
- the shared models (`AdConfig`, `NetworkConfig`, `AdError`, `AdEvent`, `BannerSize`, `RewardItem`, …);
- the `AdapterRegistry` that adapters register with from their `dartPluginClass`;
- the `ConsentProvider` / `TrackingAuthorization` abstractions;
- the pluggable `AdsLogger`, which is silent by default.

**App developers don't depend on this package directly.** `unified_ads` re-exports all of it.

It is meant for **adapter authors**. Most adapters extend `BridgedAdNetworkAdapter`, which implements the contract once:
it never throws, maps `PlatformException` → `AdError`, tracks loaded ads, and translates native events. A new adapter then
only provides its Pigeon host API. The step-by-step checklist is
[`TEMPLATE.md`](https://github.com/rsagar024/unified_ads/blob/main/packages/unified_ads_admob/TEMPLATE.md), and the
contract is described in [`ARCHITECTURE.md`](https://github.com/rsagar024/unified_ads/blob/main/ARCHITECTURE.md) §5.

```dart
class MyNetworkAdapter extends BridgedAdNetworkAdapter {
  /// Called by Flutter's plugin registrant (pubspec `dartPluginClass`).
  static void registerWith() {
    AdapterRegistry.instance.register(MyNetworkAdapter());
  }
  // ...
}
```

The core never depends on an adapter. Adapters depend only on this package, which is why an app links exactly the
networks it adds.
