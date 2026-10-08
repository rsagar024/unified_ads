// End-to-end usage of the public API exactly as documented in CLAUDE.md /
// README, against fake adapters.
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/testing.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

void main() {
  tearDown(resetAll);

  test('documented flow: init, interstitial, rewarded, banner', () async {
    final admob = FakeAdNetworkAdapter(AdNetwork.admob)..autoCloseOnShow = true;
    final unity = FakeAdNetworkAdapter(AdNetwork.unity)..autoCloseOnShow = true;
    final inmobi = FakeAdNetworkAdapter(
      AdNetwork.inmobi,
      testModeSupport: TestModeSupport.none,
    )..autoCloseOnShow = true;
    AdapterRegistry.instance
      ..register(admob)
      ..register(unity)
      ..register(inmobi);

    final result = await UnifiedAds.init(
      AdConfig(
        testMode: true,
        waterfall: const [AdNetwork.admob, AdNetwork.unity, AdNetwork.inmobi],
        networks: {
          AdNetwork.admob: const NetworkConfig(
            appId: 'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy',
            bannerAdUnitId: 'admob-banner',
            interstitialAdUnitId: 'admob-interstitial',
            rewardedAdUnitId: 'admob-rewarded',
          ),
          AdNetwork.unity: NetworkConfig(
            appId: PlatformValue.select(android: '1111111', ios: '2222222'),
            interstitialAdUnitId: 'Interstitial_Android',
            rewardedAdUnitId: 'Rewarded_Android',
          ),
          AdNetwork.inmobi: const NetworkConfig(
            appId: 'account-id',
            rewardedAdUnitId: '1234567890',
          ),
        },
      ),
    );
    expect(result.isSuccess, isTrue);
    expect(result.ready, hasLength(3));

    // Interstitial: AdMob has no fill, Unity serves.
    admob.loadError = noFill;
    final closed = <AdNetwork?>[];
    final interstitial = InterstitialAd(
      onClosed: (ad) => closed.add(ad.servedBy),
    );
    expect((await interstitial.load()).isSuccess, isTrue);
    expect(await interstitial.show(), isA<AdSuccess<void>>());
    await flush();
    expect(closed, [AdNetwork.unity]);

    // Rewarded: the reward is delivered.
    admob.loadError = null;
    RewardItem? earned;
    final rewarded = RewardedAd(onEarnedReward: (_, reward) => earned = reward);
    await rewarded.load();
    await rewarded.show();
    await flush();
    expect(earned, isNotNull);
    expect(rewarded.servedBy, AdNetwork.admob);

    // Banner: loads through the same waterfall.
    final banner = BannerAd(size: BannerSize.standard);
    expect((await banner.load()).isSuccess, isTrue);
    expect(banner.servedBy, AdNetwork.admob);
    banner.dispose();

    await UnifiedAds.dispose();
    expect(UnifiedAds.isInitialized, isFalse);
  });
}
