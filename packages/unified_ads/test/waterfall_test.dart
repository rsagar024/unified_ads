import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/testing.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

void main() {
  tearDown(resetAll);

  late FakeAdNetworkAdapter admob;
  late FakeAdNetworkAdapter unity;

  Future<void> init({
    AdConfig? config,
    List<FakeAdNetworkAdapter>? adapters,
  }) async {
    final result = await UnifiedAds.init(
      config ?? configFor([AdNetwork.admob, AdNetwork.unity]),
      adapters: adapters ?? [admob, unity],
    );
    expect(result.error, isNull);
  }

  setUp(() {
    admob = FakeAdNetworkAdapter(AdNetwork.admob);
    unity = FakeAdNetworkAdapter(AdNetwork.unity);
  });

  test('falls through to the next network and reports servedBy', () async {
    admob.loadError = noFill;
    await init();

    final ad = InterstitialAd();
    final result = await ad.load();

    expect(result.isSuccess, isTrue);
    expect(ad.servedBy, AdNetwork.unity);
    expect(admob.loadCalls.single.adUnitId, '101');
    expect(unity.loadCalls, hasLength(1));
  });

  test('stops at the first network that fills', () async {
    await init();

    final ad = RewardedAd();
    await ad.load();

    expect(ad.servedBy, AdNetwork.admob);
    expect(unity.loadCalls, isEmpty);
  });

  test('aggregates errors when every network fails', () async {
    admob.loadError = noFill;
    unity.loadError = const AdError(
      code: AdErrorCode.networkError,
      message: 'offline',
    );
    await init();

    AdError? reported;
    final ad = InterstitialAd(onFailedToLoad: (_, e) => reported = e);
    final result = await ad.load();

    final error = result.errorOrNull!;
    expect(error.code, AdErrorCode.noFill);
    expect(error.attempts.map((e) => e.network), [
      AdNetwork.admob,
      AdNetwork.unity,
    ]);
    expect(error.attempts.last.code, AdErrorCode.networkError);
    expect(reported, error);
  });

  test('a single failing network returns its own error', () async {
    admob.loadError = noFill;
    await init(config: configFor([AdNetwork.admob]), adapters: [admob]);

    final result = await InterstitialAd().load();

    expect(result.errorOrNull?.code, AdErrorCode.noFill);
    expect(result.errorOrNull?.network, AdNetwork.admob);
  });

  test('times out slow networks and destroys their late ads', () async {
    admob.loadDelay = const Duration(milliseconds: 300);
    await init(
      config: configFor([
        AdNetwork.admob,
        AdNetwork.unity,
      ], loadTimeout: const Duration(milliseconds: 50)),
    );

    final ad = InterstitialAd();
    await ad.load();
    expect(ad.servedBy, AdNetwork.unity);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(admob.destroyed, hasLength(1));
  });

  test('forceNetwork bypasses the waterfall order', () async {
    await init();

    final ad = InterstitialAd(forceNetwork: AdNetwork.unity);
    await ad.load();

    expect(ad.servedBy, AdNetwork.unity);
    expect(admob.loadCalls, isEmpty);
  });

  test('forcing an unavailable network returns the specific reason', () async {
    await init(config: configFor([AdNetwork.admob]), adapters: [admob]);

    final result = await InterstitialAd(forceNetwork: AdNetwork.inmobi).load();

    expect(result.errorOrNull?.code, AdErrorCode.invalidConfig);
    expect(result.errorOrNull?.network, AdNetwork.inmobi);
  });

  test('skips networks that do not support or enable the format', () async {
    admob = FakeAdNetworkAdapter(
      AdNetwork.admob,
      supportedFormats: {AdFormat.banner},
    );
    final config = configFor([AdNetwork.admob, AdNetwork.unity]).copyWith(
      networks: {
        AdNetwork.admob: netConfig(),
        AdNetwork.unity: netConfig(enabledFormats: {AdFormat.interstitial}),
      },
    );
    await init(config: config);

    final rewarded = await RewardedAd().load();
    expect(rewarded.errorOrNull?.code, AdErrorCode.noFill);
    expect(rewarded.errorOrNull?.attempts.map((e) => e.code), [
      AdErrorCode.unsupportedFormat,
      AdErrorCode.formatDisabled,
    ]);
    expect(admob.loadCalls, isEmpty);
    expect(unity.loadCalls, isEmpty);

    final interstitial = InterstitialAd();
    await interstitial.load();
    expect(interstitial.servedBy, AdNetwork.unity);
  });

  test(
    'skips missing ad-unit IDs unless the network does not need them',
    () async {
      final startapp = FakeAdNetworkAdapter(
        AdNetwork.startapp,
        requiresAdUnitId: false,
      );
      final config = AdConfig(
        waterfall: const [AdNetwork.admob, AdNetwork.startapp],
        networks: {
          AdNetwork.admob: netConfig(interstitial: null),
          AdNetwork.startapp: netConfig(interstitial: null),
        },
        preload: PreloadPolicy.none,
      );
      await init(config: config, adapters: [admob, startapp]);

      final ad = InterstitialAd();
      await ad.load();

      expect(ad.servedBy, AdNetwork.startapp);
      expect(startapp.loadCalls.single.adUnitId, '');
      expect(admob.loadCalls, isEmpty);
    },
  );

  test('networks missing from an explicit waterfall never serve', () async {
    final config = configFor([AdNetwork.admob]).copyWith(
      networks: {AdNetwork.admob: netConfig(), AdNetwork.unity: netConfig()},
    );
    admob.loadError = noFill;
    await init(config: config);

    final result = await InterstitialAd().load();

    expect(result.isSuccess, isFalse);
    expect(unity.loadCalls, isEmpty);
  });

  test(
    'an empty waterfall uses every configured network in enum order',
    () async {
      admob.loadError = noFill;
      final config = AdConfig(
        networks: {AdNetwork.unity: netConfig(), AdNetwork.admob: netConfig()},
        preload: PreloadPolicy.none,
      );
      await init(config: config);

      final ad = InterstitialAd();
      await ad.load();

      expect(ad.servedBy, AdNetwork.unity);
      expect(admob.loadCalls, hasLength(1));
    },
  );
}
