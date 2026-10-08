import 'package:unified_ads/src/runtime.dart';
import 'package:unified_ads/unified_ads.dart';

const noFill = AdError(code: AdErrorCode.noFill, message: 'no fill');

/// A network config with an app ID and numeric unit IDs for every format.
NetworkConfig netConfig({
  bool enabled = true,
  bool? testMode,
  Set<AdFormat>? enabledFormats,
  String? appId = 'app-id',
  String? interstitial = '101',
  String? rewarded = '102',
  String? banner = '103',
}) => NetworkConfig(
  enabled: enabled,
  appId: appId,
  testMode: testMode,
  enabledFormats: enabledFormats,
  interstitialAdUnitId: interstitial,
  rewardedAdUnitId: rewarded,
  bannerAdUnitId: banner,
);

/// A config with [networks] in waterfall order and short timeouts.
AdConfig configFor(
  List<AdNetwork> networks, {
  bool testMode = true,
  PreloadPolicy preload = PreloadPolicy.none,
  Duration loadTimeout = const Duration(milliseconds: 200),
  Map<AdFormat, FrequencyCap> frequencyCaps = const {},
  Duration cacheTtl = const Duration(hours: 1),
}) => AdConfig(
  testMode: testMode,
  waterfall: networks,
  networks: {for (final n in networks) n: netConfig()},
  loadTimeout: loadTimeout,
  preload: preload,
  frequencyCaps: frequencyCaps,
  cacheTtl: cacheTtl,
);

/// Resets all global state between tests.
Future<void> resetAll() async {
  await AdsRuntime.instance.reset();
  AdapterRegistry.instance.clear();
  AdsLogger.current = AdsLogger.silent;
}

/// Lets queued events travel through the broadcast streams.
Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A mutable clock for cache / frequency tests.
class TestClock {
  DateTime now = DateTime(2026, 10, 7, 12);

  void advance(Duration d) => now = now.add(d);
}
