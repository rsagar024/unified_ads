# unified_ads example

Add the core package plus **only** the adapters you want. Their native SDKs are the only ones linked into your app.

```yaml
dependencies:
  unified_ads: ^1.0.0
  unified_ads_admob: ^1.0.0
  unified_ads_unity: ^1.0.0
```

A minimal app: AdMob first, Unity Ads as the fallback, an anchored banner, an interstitial and a rewarded ad.

```dart
import 'package:flutter/material.dart';
import 'package:unified_ads/unified_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  UnifiedAds.logger = const AdsLogger.console(level: AdsLogLevel.info);

  final result = await UnifiedAds.init(
    AdConfig(
      testMode: true, // never ship with test mode on
      waterfall: [AdNetwork.admob, AdNetwork.unity],
      networks: {
        AdNetwork.admob: NetworkConfig(
          appId: 'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy',
          bannerAdUnitId: 'your-admob-banner-id',
          interstitialAdUnitId: 'your-admob-interstitial-id',
          rewardedAdUnitId: 'your-admob-rewarded-id',
        ),
        AdNetwork.unity: NetworkConfig(
          appId: 'your-unity-game-id',
          bannerAdUnitId: 'Banner_Android',
          interstitialAdUnitId: 'Interstitial_Android',
          rewardedAdUnitId: 'Rewarded_Android',
        ),
      },
    ),
  );
  debugPrint('ready: ${result.ready}, failed: ${result.failed}');
  runApp(const MaterialApp(home: AdsDemo()));
}

class AdsDemo extends StatefulWidget {
  const AdsDemo({super.key});

  @override
  State<AdsDemo> createState() => _AdsDemoState();
}

class _AdsDemoState extends State<AdsDemo> {
  final _banner = BannerAd();
  final _interstitial = InterstitialAd(
    onClosed: (ad) => debugPrint('interstitial from ${ad.servedBy} closed'),
  );
  final _rewarded = RewardedAd(
    onEarnedReward: (ad, reward) =>
        debugPrint('earned ${reward.amount} ${reward.type}'),
  );

  @override
  void dispose() {
    _banner.dispose();
    _interstitial.dispose();
    _rewarded.dispose();
    super.dispose();
  }

  Future<void> _show(FullScreenAd ad) async {
    // load() and show() return AdResult and never throw.
    if (!ad.isReady && !(await ad.load()).isSuccess) return;
    await ad.show();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => _show(_interstitial),
            child: const Text('Interstitial'),
          ),
          FilledButton(
            onPressed: () => _show(_rewarded),
            child: const Text('Rewarded'),
          ),
        ],
      ),
    ),
    bottomNavigationBar: UnifiedBannerWidget(ad: _banner, anchored: true),
  );
}
```

The same configuration can live in `pubspec.yaml` and be turned into an asset with
`dart run unified_ads:generate_config` (see the package README).

The repository's [example app](https://github.com/rsagar024/unified_ads/tree/master/example) is the full version. It
enables networks with checkboxes, edits IDs per format, persists settings, forces a network per banner, and shows a live
event log.
