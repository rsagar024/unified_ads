# unified_ads

One Dart API for **banner, interstitial and rewarded** ads across AdMob, AppLovin MAX, Unity Ads, ironSource LevelPlay,
InMobi, Start.io and Facebook Audience Network. Each network is a separate adapter package, so **only the SDKs you add are linked** into your app.

## Install

```yaml
dependencies:
  unified_ads: ^1.0.0
  # add only the networks you want:
  unified_ads_admob: ^1.0.0
  unified_ads_unity: ^1.0.0
```

| Adapter | Network |
|---|---|
| `unified_ads_admob` | Google AdMob (+ UMP consent provider) |
| `unified_ads_applovin` | AppLovin MAX |
| `unified_ads_unity` | Unity Ads |
| `unified_ads_ironsource` | ironSource / Unity LevelPlay |
| `unified_ads_inmobi` | InMobi |
| `unified_ads_startapp` | Start.io |
| `unified_ads_facebook` | Facebook Audience Network, branded Meta (bidding-only: test ads direct, revenue via mediation) |

## Use

```dart
await UnifiedAds.requestTrackingAuthorization();              // iOS ATT prompt
await UnifiedAds.gatherConsent(const AdmobConsentProvider()); // Google UMP
await UnifiedAds.init(AdConfig(
  testMode: true,
  waterfall: [AdNetwork.admob, AdNetwork.unity],
  networks: {
    AdNetwork.admob: NetworkConfig(appId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…'),
    AdNetwork.unity: NetworkConfig(appId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…'),
  },
));

final ad = InterstitialAd(onClosed: (ad) => debugPrint('served by ${ad.servedBy}'));
if ((await ad.load()).isSuccess) await ad.show();
```

Banners: `UnifiedBannerWidget(ad: BannerAd(size: const BannerSize.adaptiveAnchored()), anchored: true)`.
Also `RewardedInterstitialAd` and `AppOpenAd` (AdMob; MAX for app open), with the same waterfall and callbacks.
Tests: `package:unified_ads/testing.dart` (`FakeAdNetworkAdapter`).

## Declarative config

Instead of building `AdConfig` in code, you can keep the same settings in `pubspec.yaml`:

```yaml
unified_ads:
  testMode: true
  waterfall: [admob, unity]
  networks:
    admob:
      appId: {android: 'ca-app-pub-…~…', ios: 'ca-app-pub-…~…'}
      interstitialAdUnitId: '…'
    unity:
      appId: '…'
      interstitialAdUnitId: '…'

flutter:
  assets:
    - assets/ads_config.json
```

Generate the asset with `dart run unified_ads:generate_config`, then load it with
`AdConfigLoader.fromAsset('assets/ads_config.json')`. The generator validates the section and reports errors with a
JSON path. In CI, `--set-exit-if-changed` fails the build when the JSON is out of date. You can also write
`assets/ads_config.json` by hand. The schema is in the `AdConfigLoader` docs.

## Getting your ad IDs

| Network | `appId` | Per-format IDs |
|---|---|---|
| AdMob | App ID `ca-app-pub-…~…` (also in AndroidManifest + Info.plist) | ad unit IDs `ca-app-pub-…/…` |
| AppLovin MAX | SDK key | MAX ad unit IDs |
| Unity Ads | Game ID (per platform) | placement IDs |
| LevelPlay | App Key | ad unit IDs |
| InMobi | Account ID | numeric placement IDs |
| Start.io | App ID | none |
| Facebook | none (no ID in code) | placement IDs `IMG_16_9_APP_INSTALL#…` for test ads |

Step-by-step dashboard instructions and public test credentials: see
[docs/getting_ids.md](https://github.com/rsagar024/unified_ads/blob/main/docs/getting_ids.md) in the repository.

## Status

Android: every adapter compiles against its pinned SDK. AdMob, Unity Ads, Start.io and Facebook have been verified serving
test ads on a device. iOS compiles only in CI (pending its first run) and has not yet run on a device.

Requirements: Android minSdk 24; iOS 13, or iOS 15 with `unified_ads_facebook`; Flutter 3.44+.
See the repository `README.md`, `SDK_STATUS.md` and `IMPLEMENTATION.md`.
