# unified_ads_facebook

Facebook Audience Network (branded Meta Audience Network) adapter for
[`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial and rewarded**.

It links only the Audience Network SDK: `com.facebook.android:audience-network-sdk:6.22.0` on Android, and
`FBAudienceNetwork` 6.22.0 on iOS (**iOS 15+**). Apps that don't depend on this package never pull that SDK.

> **Read this first.** Audience Network has been **bidding-only since 2021**. A direct integration like this one serves
> **test ads** (test placements `IMG_16_9_APP_INSTALL#<placement id>` or registered test devices), but it is **not
> expected to fill in production**. For Facebook revenue, add Audience Network as a bidder in AdMob, AppLovin MAX or LevelPlay
> mediation. See [`doc/setup/facebook.md`](https://github.com/rsagar024/unified_ads/blob/master/doc/setup/facebook.md).

## Usage

```dart
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_facebook/unified_ads_facebook.dart';

await UnifiedAds.init(AdConfig(
  waterfall: [AdNetwork.facebook],
  networks: {
    AdNetwork.facebook: NetworkConfig(
      // Audience Network needs no app ID in code.
      bannerAdUnitId: 'IMG_16_9_APP_INSTALL#YOUR_BANNER_PLACEMENT_ID',
      interstitialAdUnitId: 'IMG_16_9_APP_INSTALL#YOUR_INTERSTITIAL_PLACEMENT_ID',
      rewardedAdUnitId: 'IMG_16_9_APP_INSTALL#YOUR_REWARDED_PLACEMENT_ID',
      testMode: true,
      testDeviceIds: ['<hashed id printed by the SDK in logcat / Xcode console>'],
      extras: {'rewardAmount': 1, 'rewardType': 'coins'}, // reward reported to Dart
    ),
  },
));
```

**Required Android app setup:** allow cleartext for `127.0.0.1` only. The SDK caches media through a local proxy, so
Android 9+ otherwise fails with AdError 7003. The snippet is in the setup doc.

Each placement must match its display format (a banner placement for banners, and so on). Otherwise the SDK returns
1011/1203, which maps to `AdErrorCode.invalidConfig`.

## Credits

The SDK call shapes were cross-checked against the (abandoned, MIT-licensed)
[`facebook_audience_network`](https://pub.dev/packages/facebook_audience_network) plugin and Google's official Meta
mediation adapters. No code was copied. Every API name was verified against the 6.22.0 SDK binaries/headers.
