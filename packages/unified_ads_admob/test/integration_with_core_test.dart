// The AdMob adapter driven through the real unified_ads core (native side
// faked), proving the adapter honours the AdNetworkAdapter contract.
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_admob/src/messages.g.dart';
import 'package:unified_ads_admob/unified_ads_admob.dart';

import 'fake_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(UnifiedAds.dispose);

  test('init → rewarded load/show → reward → close', () async {
    final host = FakeHost();
    final result = await UnifiedAds.init(
      const AdConfig(
        testMode: true,
        preload: PreloadPolicy.none,
        networks: {
          AdNetwork.admob: NetworkConfig(
            appId: 'ca-app-pub-3940256099942544~3347511713',
            rewardedAdUnitId: 'ca-app-pub-3940256099942544/5224354917',
          ),
        },
      ),
      adapters: [AdmobAdapter(hostApi: host)],
    );
    expect(result.ready, {AdNetwork.admob});

    final calls = <String>[];
    final ad = RewardedAd(
      onEarnedReward: (_, r) => calls.add('reward ${r.amount} ${r.type}'),
      onClosed: (ad) => calls.add('closed by ${ad.servedBy?.id}'),
    );
    expect((await ad.load()).isSuccess, isTrue);
    expect((await ad.show()).isSuccess, isTrue);

    for (final kind in [AdEventKind.shown, AdEventKind.closed]) {
      if (kind == AdEventKind.closed) {
        await sendNativeEvent(
          AdEventMessage(
            kind: AdEventKind.earnedReward,
            adId: 'admob-1',
            format: AdFormatMessage.rewarded,
            rewardAmount: 10,
            rewardType: 'coins',
          ),
        );
      }
      await sendNativeEvent(
        AdEventMessage(
          kind: kind,
          adId: 'admob-1',
          format: AdFormatMessage.rewarded,
        ),
      );
    }
    await pumpEventQueue();

    expect(calls, ['reward 10.0 coins', 'closed by admob']);
    expect(host.shown, ['admob-1']);
  });
}
