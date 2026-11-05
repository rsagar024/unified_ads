import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/src/runtime.dart';
import 'package:unified_ads/testing.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

void main() {
  late TestClock clock;
  late FakeAdNetworkAdapter admob;

  setUp(() {
    clock = TestClock();
    AdsRuntime.instance.clock = () => clock.now;
    admob = FakeAdNetworkAdapter(AdNetwork.admob)..autoCloseOnShow = true;
  });
  tearDown(resetAll);

  Future<void> init({
    Map<AdFormat, AdPacing> pacing = const {},
    Map<AdFormat, FrequencyCap> frequencyCaps = const {},
    FrequencyStore? store,
  }) => UnifiedAds.init(
    configFor([AdNetwork.admob], pacing: pacing, frequencyCaps: frequencyCaps),
    adapters: [admob],
    frequencyStore: store,
  );

  /// Loads a fresh interstitial and tries to show it.
  Future<AdError?> showOnce() async {
    final ad = InterstitialAd();
    await ad.load();
    final error = (await ad.show()).errorOrNull;
    await flush();
    return error;
  }

  group('AdPacing', () {
    test('minInterval enforces a cooldown between shows', () async {
      await init(
        pacing: {
          AdFormat.interstitial: const AdPacing(
            minInterval: Duration(seconds: 15),
          ),
        },
      );

      expect(await showOnce(), isNull);
      clock.advance(const Duration(seconds: 10));
      final error = await showOnce();
      expect(error?.code, AdErrorCode.frequencyCapped);
      expect(error?.message, contains('cooldown'));

      clock.advance(const Duration(seconds: 6));
      expect(await showOnce(), isNull);
    });

    test('initialDelay blocks shows right after the first init', () async {
      await init(
        pacing: {
          AdFormat.interstitial: const AdPacing(
            initialDelay: Duration(seconds: 30),
          ),
        },
      );

      final error = await showOnce();
      expect(error?.code, AdErrorCode.frequencyCapped);
      expect(error?.message, contains('initial delay'));

      clock.advance(const Duration(seconds: 20));
      await init(
        pacing: {
          AdFormat.interstitial: const AdPacing(
            initialDelay: Duration(seconds: 30),
          ),
        },
      );
      clock.advance(const Duration(seconds: 11));
      expect(await showOnce(), isNull, reason: 're-init keeps the start time');
    });

    test('showEveryActions needs N recorded actions per show', () async {
      await init(
        pacing: {AdFormat.interstitial: const AdPacing(showEveryActions: 3)},
      );

      await UnifiedAds.recordAction();
      await UnifiedAds.recordAction();
      final error = await showOnce();
      expect(error?.code, AdErrorCode.frequencyCapped);
      expect(error?.message, contains('2 so far'));

      await UnifiedAds.recordAction();
      expect(UnifiedAds.actionCount, 3);
      expect(await showOnce(), isNull);

      await UnifiedAds.recordAction();
      expect((await showOnce())?.code, AdErrorCode.frequencyCapped);
      await UnifiedAds.recordAction();
      await UnifiedAds.recordAction();
      expect(await showOnce(), isNull);
    });

    test('pacing only applies to the configured format', () async {
      await init(
        pacing: {AdFormat.interstitial: const AdPacing(showEveryActions: 5)},
      );
      final rewarded = RewardedAd();
      await rewarded.load();
      expect((await rewarded.show()).isSuccess, isTrue);
    });

    test('a cap and pacing apply together', () async {
      await init(
        frequencyCaps: {
          AdFormat.interstitial: const FrequencyCap(
            maxShows: 2,
            per: Duration(hours: 1),
          ),
        },
        pacing: {
          AdFormat.interstitial: const AdPacing(
            minInterval: Duration(minutes: 1),
          ),
        },
      );

      expect(await showOnce(), isNull);
      clock.advance(const Duration(seconds: 30));
      expect((await showOnce())?.message, contains('cooldown'));
      clock.advance(const Duration(seconds: 31));
      expect(await showOnce(), isNull);
      clock.advance(const Duration(minutes: 2));
      expect((await showOnce())?.message, contains('frequency cap'));
    });

    test('canShow() reports pacing without side effects', () async {
      await init(
        pacing: {AdFormat.interstitial: const AdPacing(showEveryActions: 2)},
      );
      final ad = InterstitialAd();
      expect(await ad.canShow(), isFalse, reason: 'not loaded');
      await ad.load();
      expect(await ad.canShow(), isFalse);
      await UnifiedAds.recordAction();
      await UnifiedAds.recordAction();
      expect(await ad.canShow(), isTrue);
      expect(admob.shown, isEmpty);
    });

    test('the action count is persisted to the store', () async {
      final store = InMemoryFrequencyStore();
      await init(
        pacing: {AdFormat.interstitial: const AdPacing(showEveryActions: 2)},
        store: store,
      );
      await UnifiedAds.recordAction();
      await UnifiedAds.recordAction();
      expect(await store.readActionCount(), 2);
      expect(await showOnce(), isNull);
      expect(await store.readActionMark(AdFormat.interstitial), 2);

      // A new process: in-memory state is gone, the store remains.
      await resetAll();
      AdsRuntime.instance.clock = () => clock.now;
      await init(
        pacing: {AdFormat.interstitial: const AdPacing(showEveryActions: 2)},
        store: store,
      );
      expect(UnifiedAds.actionCount, 2);
      expect((await showOnce())?.code, AdErrorCode.frequencyCapped);
    });
  });

  group('setAdFree', () {
    test('blocks interstitial load and show, but not rewarded', () async {
      await init();
      final loaded = InterstitialAd();
      await loaded.load();

      await UnifiedAds.setAdFree(true);
      expect(UnifiedAds.isAdFree, isTrue);
      expect((await loaded.show()).errorOrNull?.code, AdErrorCode.adsBlocked);
      expect(await loaded.canShow(), isFalse);
      expect(
        (await InterstitialAd().load()).errorOrNull?.code,
        AdErrorCode.adsBlocked,
      );
      expect(
        (await AppOpenAd().load()).errorOrNull?.code,
        AdErrorCode.adsBlocked,
      );
      expect(admob.shown, isEmpty);

      final rewarded = RewardedAd();
      await rewarded.load();
      expect((await rewarded.show()).isSuccess, isTrue);
    });

    test('blockRewarded blocks rewarded formats too', () async {
      await init();
      await UnifiedAds.setAdFree(true, blockRewarded: true);
      expect(
        (await RewardedAd().load()).errorOrNull?.code,
        AdErrorCode.adsBlocked,
      );
      expect(UnifiedAds.isBlocked(AdFormat.rewardedInterstitial), isTrue);
    });

    test('drops cached ads and refuses to preload', () async {
      await init();
      await UnifiedAds.preload(AdFormat.interstitial);
      expect(UnifiedAds.hasCachedAd(AdFormat.interstitial), isTrue);

      await UnifiedAds.setAdFree(true);
      expect(UnifiedAds.hasCachedAd(AdFormat.interstitial), isFalse);
      expect(admob.destroyed, hasLength(1));
      expect(
        (await UnifiedAds.preload(AdFormat.interstitial)).errorOrNull?.code,
        AdErrorCode.adsBlocked,
      );
    });

    test('works before init and survives re-init', () async {
      final changes = <bool>[];
      final sub = UnifiedAds.adFreeChanges.listen(changes.add);
      await UnifiedAds.setAdFree(true);
      await init();
      expect(UnifiedAds.isBlocked(AdFormat.interstitial), isTrue);

      await UnifiedAds.setAdFree(false);
      expect(await showOnce(), isNull);
      await flush();
      expect(changes, [true, false]);
      await sub.cancel();
    });

    test('collapses a loaded banner and reloads it afterwards', () async {
      await init();
      final banner = BannerAd();
      await banner.load(width: 320);
      expect(banner.state, BannerAdState.loaded);

      await UnifiedAds.setAdFree(true);
      await flush();
      expect(banner.state, BannerAdState.failed);
      expect(banner.error?.code, AdErrorCode.adsBlocked);
      expect(banner.current, isNull);
      expect((await banner.load()).errorOrNull?.code, AdErrorCode.adsBlocked);

      await UnifiedAds.setAdFree(false);
      await flush();
      expect(banner.state, BannerAdState.idle);
      expect((await banner.load(width: 320)).isSuccess, isTrue);
      banner.dispose();
    });
  });
}
