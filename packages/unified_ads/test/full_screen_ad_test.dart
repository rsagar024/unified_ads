import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/testing.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

void main() {
  tearDown(resetAll);

  late FakeAdNetworkAdapter admob;

  Future<void> init({PreloadPolicy preload = PreloadPolicy.none}) async {
    await UnifiedAds.init(
      configFor([AdNetwork.admob], preload: preload),
      adapters: [admob],
    );
  }

  setUp(() => admob = FakeAdNetworkAdapter(AdNetwork.admob));

  group('InterstitialAd', () {
    test('fails with notInitialized before init', () async {
      AdError? loadError;
      final ad = InterstitialAd(onFailedToLoad: (_, e) => loadError = e);

      final load = await ad.load();
      final show = await ad.show();

      expect(load.errorOrNull?.code, AdErrorCode.notInitialized);
      expect(loadError?.code, AdErrorCode.notInitialized);
      expect(show.errorOrNull?.code, AdErrorCode.notInitialized);
    });

    test('load → show → click → close fires callbacks in order', () async {
      await init();
      final calls = <String>[];
      final ad = InterstitialAd(
        onLoaded: (_) => calls.add('loaded'),
        onShown: (_) => calls.add('shown'),
        onImpression: (_) => calls.add('impression'),
        onClicked: (_) => calls.add('clicked'),
        onClosed: (_) => calls.add('closed'),
      );

      await ad.load();
      expect(ad.isReady, isTrue);
      expect((await ad.show()).isSuccess, isTrue);
      expect(ad.isShowing, isTrue);
      expect(ad.isReady, isFalse);

      final handle = admob.shown.single;
      admob
        ..simulateClick(handle)
        ..simulateClose(handle);
      await flush();

      expect(calls, ['loaded', 'shown', 'impression', 'clicked', 'closed']);
      expect(ad.isShowing, isFalse);
      expect(ad.servedBy, AdNetwork.admob);
      expect((await ad.show()).errorOrNull?.code, AdErrorCode.notReady);
    });

    test('load() again after close loads a new ad', () async {
      admob.autoCloseOnShow = true;
      await init();
      final ad = InterstitialAd();

      await ad.load();
      await ad.show();
      await flush();
      await ad.load();

      expect(ad.isReady, isTrue);
      expect(admob.loadCalls, hasLength(2));
    });

    test('only one full-screen ad can show at a time', () async {
      await init();
      final first = InterstitialAd();
      final second = RewardedAd();
      await first.load();
      await second.load();

      await first.show();
      final blocked = await second.show();
      expect(blocked.errorOrNull?.code, AdErrorCode.alreadyShowing);

      admob.simulateClose(admob.shown.single);
      await flush();
      expect((await second.show()).isSuccess, isTrue);
    });

    test('an adapter show failure is reported once and resets state', () async {
      admob.showError = const AdError(
        code: AdErrorCode.showFailed,
        message: 'no activity',
      );
      await init();
      final errors = <AdError>[];
      final ad = InterstitialAd(onFailedToShow: (_, e) => errors.add(e));
      await ad.load();

      final result = await ad.show();

      expect(result.errorOrNull?.code, AdErrorCode.showFailed);
      expect(errors, hasLength(1));
      expect(ad.isShowing, isFalse);

      admob.showError = null;
      final other = InterstitialAd();
      await other.load();
      expect((await other.show()).isSuccess, isTrue, reason: 'not blocked');
    });

    test('an AdFailedToShow event ends the show', () async {
      await init();
      final errors = <AdError>[];
      final ad = InterstitialAd(onFailedToShow: (_, e) => errors.add(e));
      await ad.load();
      await ad.show();

      final handle = admob.shown.single;
      admob.emit(
        AdFailedToShow(
          network: AdNetwork.admob,
          adId: handle.id,
          format: AdFormat.interstitial,
          error: const AdError(code: AdErrorCode.showFailed, message: 'x'),
        ),
      );
      await flush();

      expect(errors.single.code, AdErrorCode.showFailed);
      expect(ad.isShowing, isFalse);
    });

    test('exceptions thrown by an adapter become internal errors', () async {
      final throwing = _ThrowingAdapter(AdNetwork.admob);
      await UnifiedAds.init(configFor([AdNetwork.admob]), adapters: [throwing]);

      final result = await InterstitialAd().load();

      expect(result.errorOrNull?.code, AdErrorCode.internal);
      expect(result.errorOrNull?.network, AdNetwork.admob);
      expect(result.errorOrNull?.message, contains('native crash'));
    });

    test('a throwing app callback does not break the ad', () async {
      await init();
      final ad = InterstitialAd(onLoaded: (_) => throw StateError('app bug'));

      final result = await ad.load();

      expect(result.isSuccess, isTrue);
      expect(ad.isReady, isTrue);
    });

    test('dispose destroys an unshown ad', () async {
      await init();
      final ad = InterstitialAd();
      await ad.load();

      await ad.dispose();

      expect(admob.destroyed, hasLength(1));
      expect(ad.isReady, isFalse);
      expect((await ad.load()).errorOrNull?.code, AdErrorCode.notReady);
    });

    test('re-initialization invalidates loaded ads', () async {
      await init();
      final ad = InterstitialAd();
      await ad.load();

      await init();

      expect(ad.isReady, isFalse);
      expect((await ad.show()).errorOrNull?.code, AdErrorCode.notReady);
    });

    test('the next ad is preloaded after close', () async {
      admob.autoCloseOnShow = true;
      await init(preload: const PreloadPolicy());
      final ad = InterstitialAd();
      await ad.load();

      await ad.show();
      await flush();

      expect(UnifiedAds.hasCachedAd(AdFormat.interstitial), isTrue);
      expect(admob.loadCalls, hasLength(2));

      final next = InterstitialAd();
      await next.load();
      expect(next.isReady, isTrue);
      expect(admob.loadCalls, hasLength(2), reason: 'served from cache');
      expect(UnifiedAds.hasCachedAd(AdFormat.interstitial), isFalse);
    });

    test('UnifiedAds.preload fills the cache', () async {
      await init();

      expect((await UnifiedAds.preload(AdFormat.rewarded)).isSuccess, isTrue);
      expect(UnifiedAds.hasCachedAd(AdFormat.rewarded), isTrue);
      expect(
        (await UnifiedAds.preload(AdFormat.banner)).errorOrNull?.code,
        AdErrorCode.unsupportedFormat,
      );
    });
  });

  group('RewardedAd', () {
    test('delivers the reward before close', () async {
      admob.reward = const RewardItem(amount: 5, type: 'gems');
      await init();
      final calls = <String>[];
      final ad = RewardedAd(
        onEarnedReward: (_, reward) => calls.add('reward ${reward.amount}'),
        onClosed: (_) => calls.add('closed'),
      );

      await ad.load();
      await ad.show();
      admob.simulateClose(admob.shown.single);
      await flush();

      expect(calls, ['reward 5', 'closed']);
      expect(ad.reward, const RewardItem(amount: 5, type: 'gems'));
    });
  });

  group('stretch formats', () {
    late FakeAdNetworkAdapter unity;

    const allFormats = {
      AdFormat.banner,
      AdFormat.interstitial,
      AdFormat.rewarded,
      AdFormat.rewardedInterstitial,
      AdFormat.appOpen,
    };

    Future<void> initStretch({PreloadPolicy preload = PreloadPolicy.none}) {
      admob = FakeAdNetworkAdapter(
        AdNetwork.admob,
        supportedFormats: allFormats,
      );
      // Unity is first in the waterfall but has neither stretch format.
      unity = FakeAdNetworkAdapter(AdNetwork.unity);
      const ids = NetworkConfig(
        appId: 'app-id',
        rewardedInterstitialAdUnitId: 'ri-unit',
        appOpenAdUnitId: 'open-unit',
      );
      return UnifiedAds.init(
        AdConfig(
          waterfall: const [AdNetwork.unity, AdNetwork.admob],
          networks: const {AdNetwork.unity: ids, AdNetwork.admob: ids},
          preload: preload,
        ),
        adapters: [unity, admob],
      );
    }

    test('RewardedInterstitialAd delivers the reward before close', () async {
      await initStretch();
      admob.reward = const RewardItem(amount: 3, type: 'lives');
      final calls = <String>[];
      final ad = RewardedInterstitialAd(
        onEarnedReward: (_, reward) => calls.add('reward ${reward.amount}'),
        onClosed: (_) => calls.add('closed'),
      );

      expect((await ad.load()).isSuccess, isTrue);
      expect(ad.servedBy, AdNetwork.admob);
      expect(
        unity.loadCalls,
        isEmpty,
        reason: 'unsupported formats are skipped',
      );
      await ad.show();
      admob.simulateClose(admob.shown.single);
      await flush();

      expect(calls, ['reward 3', 'closed']);
      expect(ad.reward, const RewardItem(amount: 3, type: 'lives'));
      expect(admob.shown.single.format, AdFormat.rewardedInterstitial);
    });

    test('AppOpenAd loads from the network that supports it', () async {
      await initStretch();
      final calls = <String>[];
      final ad = AppOpenAd(
        onShown: (_) => calls.add('shown'),
        onClosed: (_) => calls.add('closed'),
      );

      expect((await ad.load()).isSuccess, isTrue);
      expect(ad.servedBy, AdNetwork.admob);
      expect(admob.loadCalls.single, (
        format: AdFormat.appOpen,
        adUnitId: 'open-unit',
      ));
      await ad.show();
      admob.simulateClose(admob.shown.single);
      await flush();

      expect(calls, ['shown', 'closed']);
    });

    test(
      'a forced network without the format reports unsupportedFormat',
      () async {
        await initStretch();
        final result = await AppOpenAd(forceNetwork: AdNetwork.unity).load();
        expect(result.errorOrNull?.code, AdErrorCode.unsupportedFormat);
      },
    );

    test('app open ads can be preloaded on init', () async {
      await initStretch(
        preload: const PreloadPolicy(formats: {AdFormat.appOpen}, onInit: true),
      );
      await flush();

      expect(UnifiedAds.hasCachedAd(AdFormat.appOpen), isTrue);
      final ad = AppOpenAd();
      expect((await ad.load()).isSuccess, isTrue);
      expect(admob.loadCalls, hasLength(1), reason: 'served from the cache');
    });
  });

  test('events are also published on UnifiedAds.events', () async {
    admob.autoCloseOnShow = true;
    await init();
    final kinds = <String>[];
    final sub = UnifiedAds.events.listen((e) => kinds.add(e.kind));

    final ad = InterstitialAd();
    await ad.load();
    await ad.show();
    await flush();
    await sub.cancel();

    expect(kinds, ['loaded', 'shown', 'impression', 'closed']);
  });
}

class _ThrowingAdapter extends FakeAdNetworkAdapter {
  _ThrowingAdapter(super.network);

  @override
  Future<AdResult<AdHandle>> load(AdFormat format, String adUnitId) =>
      throw StateError('native crash');
}
