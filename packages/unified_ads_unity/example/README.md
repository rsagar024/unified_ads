# unified_ads_unity example

Add the core package and this adapter. Only the Unity Ads SDK is linked into your app.

```yaml
dependencies:
  unified_ads: ^1.0.0
  unified_ads_unity: ^1.0.0
```

The adapter registers itself through Flutter's plugin registrant, so you don't need to import it.

```dart
import 'package:flutter/widgets.dart';
import 'package:unified_ads/unified_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UnifiedAds.init(AdConfig(
    testMode: true, // never ship with test mode on
    networks: {
      AdNetwork.unity: NetworkConfig(
        appId: 'your-game-id', // Unity Game ID
        bannerAdUnitId: 'your-banner-id',
        interstitialAdUnitId: 'your-interstitial-id',
        rewardedAdUnitId: 'your-rewarded-id',
      ),
    },
  ));

  final rewarded = RewardedAd(
    onEarnedReward: (ad, reward) =>
        debugPrint('${reward.amount} ${reward.type} from ${ad.servedBy}'),
  );
  if ((await rewarded.load()).isSuccess) await rewarded.show();
}
```

Banner: `UnifiedBannerWidget(ad: BannerAd(size: const BannerSize.adaptiveAnchored()), anchored: true)`.

Platform setup (manifest, Info.plist, SKAdNetwork IDs): [`docs/setup/unity.md`](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/unity.md).
For a full app with every network, a settings screen and a live event log, see the
[example app](https://github.com/rsagar024/unified_ads/tree/main/example).
