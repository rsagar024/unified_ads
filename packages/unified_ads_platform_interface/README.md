# unified_ads_platform_interface

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_platform_interface.svg)](https://pub.dev/packages/unified_ads_platform_interface)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

The common platform interface for [`unified_ads`](https://pub.dev/packages/unified_ads). It contains:

- the `AdNetworkAdapter` contract that every network adapter implements;
- the shared models (`AdConfig`, `NetworkConfig`, `AdError`, `AdEvent`, `BannerSize`, `RewardItem`, …);
- the `AdapterRegistry` that adapters register with from their `dartPluginClass`;
- the `ConsentProvider` / `TrackingAuthorization` abstractions;
- the pluggable `AdsLogger`, which is silent by default.

**App developers don't depend on this package directly.** `unified_ads` re-exports all of it.

## For adapter authors

Most adapters extend `BridgedAdNetworkAdapter`, which implements the contract once: it never throws, maps
`PlatformException` → `AdError`, tracks loaded ads, and translates native events. A new adapter then only provides its
Pigeon host API. The step-by-step checklist is [`TEMPLATE.md`](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads_admob/TEMPLATE.md) in the AdMob
adapter, and the full contract is below.

```dart
class MyNetworkAdapter extends BridgedAdNetworkAdapter {
  /// Called by Flutter's plugin registrant (pubspec `dartPluginClass`).
  static void registerWith() {
    AdapterRegistry.instance.register(MyNetworkAdapter());
  }
  // ...
}
```

Checklist for a new adapter (`unified_ads_<network>`):

1. Depend only on `unified_ads_platform_interface` and **your own** native SDK, never on core or another adapter.
2. Declare both `pluginClass` and `dartPluginClass` in `pubspec.yaml`; register in `registerWith()`.
3. Declare the SDK only in your `android/build.gradle.kts` and `ios/<package>/Package.swift` (exact pin); ship
   `consumer-rules.pro`.
4. Define `pigeons/messages.dart` (`<Network>HostApi` + `<Network>EventsApi`); run every SDK call on the main thread.
5. Map every SDK error to an `AdErrorCode`, keeping the original in `nativeCode`; never throw across the boundary.
6. Register the banner view type `dev.arovyx.plugin.unifiedads/<network>/banner`.
7. Implement `applyConsent` for every `ConsentState` field the SDK supports.

The core never depends on an adapter. Adapters depend only on this package, which is why an app links exactly the
networks it adds.

## The `AdNetworkAdapter` contract

```dart
abstract class AdNetworkAdapter {
  AdNetwork get network;
  Set<AdFormat> get supportedFormats;      // empty for documented stubs
  TestModeSupport get testModeSupport;     // flag | testDevices | testSuiteOnly | none
  bool get requiresAdUnitId => true;       // false for app-ID-only networks (Start.io)

  Future<AdResult<void>> initialize(NetworkConfig config, {required bool testMode}); // idempotent, never throws
  Future<AdResult<AdHandle>> load(AdFormat format, String adUnitId);
  Future<AdResult<void>> show(AdHandle handle);
  bool isReady(AdHandle handle);
  Future<void> destroy(AdHandle handle);

  String get bannerViewType;               // 'dev.arovyx.plugin.unifiedads/<network>/banner'
  Map<String, Object?> bannerCreationParams(BannerRequest request);

  Future<void> applyConsent(ConsentState state);
  Stream<AdEvent> get events;              // broadcast; every event carries network + adId
  Future<void> dispose();                  // safe to call twice; initialize may follow
}
```

| Concern | Contract |
|---|---|
| Errors | adapters **never throw**; native exceptions and SDK codes map to `AdError(code, message, network, nativeCode)` |
| Unsupported | a format not in `supportedFormats` returns `unsupportedFormat` without touching native code |
| Ordering | adapters normalise native quirks (e.g. buffer a reward the SDK fires after close) |
| Show completion | `show` completes when the ad is presented (or failed to); closing is signalled by `AdClosed` |
| Threading | all native SDK and UI calls run on the platform main thread |

All seven native adapters extend **`BridgedAdNetworkAdapter`**, which implements the contract once (never throwing,
error mapping, loaded-ad tracking, event translation), so each adapter only bridges its native calls.

**Native bridge (Pigeon 29):** each adapter owns `pigeons/messages.dart` → `@HostApi() <Network>HostApi`
(`initialize`, `load`, `show`, `isReady`, `destroy`, `applyConsent`, `dispose`) and `@FlutterApi() <Network>EventsApi`
(`onAdEvent`). Channels are `dev.flutter.pigeon.unified_ads_<network>.…`, so adapters never collide. Kotlin gets
`suspend` methods; Swift gets `async throws` methods delegating to `@MainActor` code; native → Dart events go through an
ordered main-thread queue.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
