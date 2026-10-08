import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/src/ad_cache.dart';
import 'package:unified_ads/src/frequency.dart';
import 'package:unified_ads/src/runtime.dart';
import 'package:unified_ads/testing.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

AdHandle _handle(String id, {AdFormat format = AdFormat.interstitial}) =>
    AdHandle(
      id: id,
      network: AdNetwork.admob,
      format: format,
      adUnitId: 'u',
      loadedAt: DateTime(2026),
    );

void main() {
  late TestClock clock;

  setUp(() {
    clock = TestClock();
    AdsRuntime.instance.clock = () => clock.now;
  });
  tearDown(resetAll);

  group('AdCache', () {
    test('stores one handle per format and expires it', () {
      final cache = AdCache(
        ttl: const Duration(minutes: 10),
        now: () => clock.now,
      );

      expect(cache.put(_handle('a')), isNull);
      expect(cache.put(_handle('b')), _handle('a'));
      expect(cache.has(AdFormat.interstitial), isTrue);
      expect(cache.has(AdFormat.rewarded), isFalse);

      clock.advance(const Duration(minutes: 10));
      AdHandle? expired;
      expect(
        cache.take(AdFormat.interstitial, expired: (h) => expired = h),
        isNull,
      );
      expect(expired, _handle('b'));
    });

    test('clear returns every handle', () {
      final cache = AdCache(ttl: const Duration(hours: 1), now: () => clock.now)
        ..put(_handle('a'))
        ..put(_handle('b', format: AdFormat.rewarded));

      expect(cache.clear(), hasLength(2));
      expect(cache.has(AdFormat.interstitial), isFalse);
    });
  });

  group('FrequencyLimiter', () {
    test('allows maxShows per sliding window', () async {
      final limiter = FrequencyLimiter(
        caps: {
          AdFormat.interstitial: const FrequencyCap(
            maxShows: 2,
            per: Duration(minutes: 30),
          ),
        },
        store: InMemoryFrequencyStore(),
        now: () => clock.now,
      );

      expect(await limiter.canShow(AdFormat.interstitial), isTrue);
      await limiter.record(AdFormat.interstitial);
      clock.advance(const Duration(minutes: 10));
      await limiter.record(AdFormat.interstitial);
      expect(await limiter.canShow(AdFormat.interstitial), isFalse);
      expect(
        await limiter.canShow(AdFormat.rewarded),
        isTrue,
        reason: 'uncapped',
      );

      clock.advance(const Duration(minutes: 21));
      expect(await limiter.canShow(AdFormat.interstitial), isTrue);
    });
  });

  test('expired cached ads are destroyed and replaced', () async {
    final admob = FakeAdNetworkAdapter(AdNetwork.admob);
    await UnifiedAds.init(
      configFor([AdNetwork.admob], cacheTtl: const Duration(minutes: 30)),
      adapters: [admob],
    );
    await UnifiedAds.preload(AdFormat.interstitial);

    clock.advance(const Duration(minutes: 31));
    final ad = InterstitialAd();
    await ad.load();

    expect(admob.destroyed, hasLength(1));
    expect(admob.loadCalls, hasLength(2));
    expect(ad.isReady, isTrue);
  });

  test('show() respects the frequency cap and persists to the store', () async {
    final admob = FakeAdNetworkAdapter(AdNetwork.admob)..autoCloseOnShow = true;
    final store = InMemoryFrequencyStore();
    await UnifiedAds.init(
      configFor(
        [AdNetwork.admob],
        frequencyCaps: {
          AdFormat.interstitial: const FrequencyCap(
            maxShows: 1,
            per: Duration(hours: 1),
          ),
        },
      ),
      adapters: [admob],
      frequencyStore: store,
    );

    final first = InterstitialAd();
    await first.load();
    expect((await first.show()).isSuccess, isTrue);
    await flush();

    final second = InterstitialAd();
    await second.load();
    expect(
      (await second.show()).errorOrNull?.code,
      AdErrorCode.frequencyCapped,
    );
    expect(await store.read(AdFormat.interstitial), hasLength(1));
    expect(second.isReady, isTrue, reason: 'a capped ad stays loaded');

    clock.advance(const Duration(hours: 1, seconds: 1));
    expect((await second.show()).isSuccess, isTrue);
  });
}
