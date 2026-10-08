# unified_ads_admob example

Add the core package and this adapter. Only the AdMob SDK is linked into your app.

```yaml
dependencies:
  unified_ads: ^1.0.0
  unified_ads_admob: ^1.0.0
```

The adapter registers itself through Flutter's plugin registrant. Import it only for `AdmobConsentProvider`.

```dart
import 'package:flutter/widgets.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_admob/unified_ads_admob.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Optional: iOS App Tracking Transparency, then Google UMP consent.
  await UnifiedAds.requestTrackingAuthorization();
  await UnifiedAds.gatherConsent(const AdmobConsentProvider());

  await UnifiedAds.init(AdConfig(
    testMode: true, // never ship with test mode on
    networks: {
      AdNetwork.admob: NetworkConfig(
        appId: 'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy', // also in AndroidManifest + Info.plist
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

Platform setup (manifest, Info.plist, SKAdNetwork IDs): [`docs/setup/admob.md`](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/admob.md).
For a full app with every network, a settings screen and a live event log, see the
[example app](https://github.com/rsagar024/unified_ads/tree/main/example).
