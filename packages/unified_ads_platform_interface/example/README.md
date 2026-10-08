# unified_ads_platform_interface example

App developers use [`unified_ads`](https://pub.dev/packages/unified_ads) instead. This package is for writing an
**adapter**.

The skeleton below shows the whole Dart side of an adapter. The base class implements the `AdNetworkAdapter` contract,
so a concrete adapter only has to:

- bridge six native calls, usually through a Pigeon host API;
- forward native callbacks to `emitNativeEvent`.

```dart
import 'package:flutter/services.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

class MyNetworkAdapter extends BridgedAdNetworkAdapter {
  /// Called by Flutter's plugin registrant: list this class as the
  /// `dartPluginClass` of the adapter's pubspec `flutter: plugin:` section.
  static void registerWith() {
    AdapterRegistry.instance.register(MyNetworkAdapter());
  }

  static const _channel = MethodChannel('com.example.my_network');

  @override
  AdNetwork get network => AdNetwork.inmobi; // the network this adapter serves

  @override
  Set<AdFormat> get supportedFormats =>
      {AdFormat.banner, AdFormat.interstitial, AdFormat.rewarded};

  @override
  TestModeSupport get testModeSupport => TestModeSupport.flag;

  @override
  String get bannerViewType => 'com.example.my_network/banner';

  @override
  Map<String, Object?> bannerCreationParams(BannerRequest request) => {
    'adId': request.adId,
    'adUnitId': request.adUnitId,
    'testMode': request.testMode,
  };

  @override
  void listenToNativeEvents() {
    _channel.setMethodCallHandler((call) async {
      final args = (call.arguments as Map<Object?, Object?>).cast<String, Object?>();
      emitNativeEvent(
        kind: call.method, // 'loaded', 'shown', 'closed', ...
        adId: args['adId']! as String,
        format: args['format']! as String,
        errorCode: args['errorCode'] as String?,
        errorMessage: args['errorMessage'] as String?,
        nativeCode: args['nativeCode'] as String?,
      );
    });
  }

  // Native failures are PlatformExceptions whose `code` is an AdErrorCode name;
  // the base class maps them to AdError and never lets them escape.
  @override
  Future<void> nativeInitialize(NetworkConfig config, {required bool testMode}) =>
      _channel.invokeMethod('initialize', {'appId': config.appId, 'testMode': testMode});

  @override
  Future<String> nativeLoad(AdFormat format, String adUnitId) async =>
      (await _channel.invokeMethod<String>('load', {'format': format.id, 'adUnitId': adUnitId}))!;

  @override
  Future<void> nativeShow(String adId) => _channel.invokeMethod('show', adId);

  @override
  Future<void> nativeDestroy(String adId) => _channel.invokeMethod('destroy', adId);

  @override
  Future<void> nativeApplyConsent(ConsentState state) =>
      _channel.invokeMethod('applyConsent', {'gdprApplies': state.gdprApplies});

  @override
  Future<void> nativeDispose() => _channel.invokeMethod('dispose');
}
```

The repository's adapters use Pigeon instead of a raw `MethodChannel`, which gives type-safe Kotlin and Swift bindings.
Copy one of them by following
[`TEMPLATE.md`](https://github.com/rsagar024/unified_ads/blob/main/packages/unified_ads_admob/TEMPLATE.md).
The native SDK dependency goes **only** in the adapter's `build.gradle.kts` and podspec. That is what keeps networks
opt-in.
