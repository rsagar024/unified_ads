# unified_ads

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![pub package](https://img.shields.io/pub/v/unified_ads.svg)](https://pub.dev/packages/unified_ads)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**One Dart API for banner, interstitial and rewarded ads across AdMob, AppLovin MAX, Unity Ads, ironSource LevelPlay,
InMobi, Start.io and Facebook Audience Network, linking only the ad SDKs you choose.**

```dart
await UnifiedAds.init(AdConfig(
  testMode: true,
  waterfall: [AdNetwork.admob, AdNetwork.unity, AdNetwork.inmobi],
  networks: {
    AdNetwork.admob: NetworkConfig(appId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…'),
    AdNetwork.unity: NetworkConfig(appId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…'),
    AdNetwork.inmobi: NetworkConfig(appId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…'),
  },
));

final ad = InterstitialAd(onClosed: (ad) => print('served by ${ad.servedBy}'));
if ((await ad.load()).isSuccess) await ad.show();   // tries AdMob → Unity → InMobi
```

## Why

- **Opt-in networks:** each network is its own package. Depend on `unified_ads_admob` + `unified_ads_unity` and *only*
  those SDKs end up in your APK / IPA. CI checks this on every push: [`tool/verify_opt_in.sh`](tool/verify_opt_in.sh)
  builds an app with AdMob + Unity + InMobi and fails if any other network's Gradle artifact or pod is resolved. See
  [ARCHITECTURE.md §4](ARCHITECTURE.md).
- **Waterfall fallback** with per-network timeouts, **preloading**, **frequency capping**, one `AdError` model, and unified events.
- **Never crashes the host app:** every native failure becomes an `AdError`.
- **Consent and ATT:** a Google UMP provider, a pluggable `ConsentProvider`, and an App Tracking Transparency helper
  ([docs/consent_and_att.md](docs/consent_and_att.md)).
- **Config in code or in `pubspec.yaml`:** `AdConfig`, or a declarative `unified_ads:` section turned into
  `ads_config.json` by `dart run unified_ads:generate_config`.

## Packages

| Package | Purpose |
|---|---|
| [`unified_ads`](packages/unified_ads) | Public API: `UnifiedAds`, `InterstitialAd`, `RewardedAd`, `BannerAd`, `UnifiedBannerWidget` |
| [`unified_ads_platform_interface`](packages/unified_ads_platform_interface) | Adapter contract + shared models |
| [`unified_ads_admob`](packages/unified_ads_admob) | Google AdMob + UMP consent |
| [`unified_ads_applovin`](packages/unified_ads_applovin) | AppLovin MAX |
| [`unified_ads_unity`](packages/unified_ads_unity) | Unity Ads |
| [`unified_ads_ironsource`](packages/unified_ads_ironsource) | ironSource / Unity LevelPlay |
| [`unified_ads_inmobi`](packages/unified_ads_inmobi) | InMobi |
| [`unified_ads_startapp`](packages/unified_ads_startapp) | Start.io |
| [`unified_ads_facebook`](packages/unified_ads_facebook) | Facebook Audience Network, branded Meta (bidding-only: test ads direct, revenue via mediation) |

## Feature matrix

| Network | Banner | Interstitial | Rewarded | Rewarded interstitial | App open | Meta bidding ³ | Android | iOS | Package min (Android API / iOS) | Test mode | Device-verified (Android) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| AdMob | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ opt-in | ✅ (GMA Next-Gen) | ⏳ CI | 24 / 13 | test devices | ✅ test ads serve (all 5 formats load; Next-Gen) |
| AppLovin MAX | ✅ | ✅ | ✅ | — | ✅ | ✅ opt-in | ✅ | ⏳ CI | 24 / 13 | test devices | needs your SDK key |
| Unity Ads | ✅ | ✅ | ✅ | — | — | — | ✅ | ⏳ CI | 24 / 13 | flag | ✅ test ads serve |
| LevelPlay | ✅ | ✅ | ✅ | — | — | ✅ opt-in | ✅ | ⏳ CI | 24 / 13 | test suite only ² | initializes; fill needs your app key + networks |
| InMobi | ✅ | ✅ | ✅ | — | — | — | ✅ | ⏳ CI | 24 / 13 | dashboard only ² | initializes; fill needs your placements |
| Start.io | ✅ | ✅ | ✅ | — | — | — | ✅ | ⏳ CI | 24 / 13 | flag | ✅ test ads serve |
| Facebook Audience Network ¹ | ✅ | ✅ | ✅ | — | — | n/a | ✅ | ⏳ CI | 24 / **15** | test devices | ✅ banner + interstitial test ads; rewarded needs your placement |

¹ Bidding-only: a direct load serves test ads but is not expected to fill in production; see [setup](docs/setup/facebook.md).
² `testMode` cannot force test ads for this network; init logs a warning. Use the vendor's dashboard or test suite.
³ Meta (Facebook) demand through the mediation platform's bidding. You opt in by adding the vendor's Meta adapter to your
app; the package detects it and forwards privacy. No Meta SDK is linked otherwise. See the network's setup doc.
"—" = the SDK has no such format; the waterfall skips that network for it.

Column legend:

- ✅ **Android:** compiled against the pinned SDK, with Kotlin and Dart unit tests.
- ⏳ **CI (iOS):** Swift sources are built by the CI macOS job (`flutter build ios --no-codesign`, SPM + CocoaPods
  dynamic/static). That job hasn't had its first run yet, and iOS hasn't run on a device.

`RewardedInterstitialAd` and `AppOpenAd` use the same waterfall, cache, frequency caps and callbacks as the other formats.
AdMob Android uses the **GMA Next-Gen SDK**, which can't share an app with the legacy `play-services-ads` (for example the
official `google_mobile_ads` plugin); see [the migration note](docs/migration/1.0.0-admob-next-gen.md). Versions and caveats
are in [SDK_STATUS.md](SDK_STATUS.md).

## Getting your ad IDs

Every network needs an **app-level credential**, and most also need **one ID per ad format**:

| Network | App-level credential → `appId` | Banner / interstitial / rewarded IDs | Where |
|---|---|---|---|
| AdMob | App ID `ca-app-pub-…~…` (**also in AndroidManifest + Info.plist**) | Ad unit IDs `ca-app-pub-…/…` | admob.google.com → Apps → Ad units |
| AppLovin MAX | SDK key | MAX ad unit IDs (tied to your package name) | dash.applovin.com → Account → Keys; MAX → Mediation → Ad Units |
| Unity Ads | Game ID (Android + iOS) | Placement IDs | cloud.unity.com → project Settings / Placements |
| LevelPlay | App Key | Ad unit IDs (+ enable demand networks) | platform.ironsrc.com → Apps / Ad units |
| InMobi | Account ID | Numeric placement IDs | InMobi dashboard → Inventory → placements |
| Start.io | App ID | none (optional ad tags) | portal.start.io → Add New App |
| Facebook Audience Network | none | Placement IDs (one per format; `IMG_16_9_APP_INSTALL#` prefix for test ads) | Monetization Manager → Properties → Placements |

**➡ Step-by-step instructions for every dashboard, plus public test credentials: [docs/getting_ids.md](docs/getting_ids.md)**

## Quick start

1. Add the core and the networks you want:
   ```yaml
   dependencies:
     unified_ads: ^1.0.0
     unified_ads_admob: ^1.0.0
     unified_ads_unity: ^1.0.0
   ```
2. Follow each network's setup doc (manifest / Info.plist entries, SKAdNetwork IDs, privacy):
   [AdMob](docs/setup/admob.md) · [AppLovin MAX](docs/setup/applovin.md) · [Unity Ads](docs/setup/unity.md) ·
   [LevelPlay](docs/setup/ironsource.md) · [InMobi](docs/setup/inmobi.md) · [Start.io](docs/setup/startapp.md) ·
   [Facebook Audience Network](docs/setup/facebook.md)
3. At startup: **ATT → consent → init**:
   ```dart
   await UnifiedAds.requestTrackingAuthorization();              // iOS prompt; no-op on Android
   await UnifiedAds.gatherConsent(const AdmobConsentProvider()); // Google UMP form if required
   final result = await UnifiedAds.init(config);                 // never throws; see result.failed / skipped
   ```
4. Or keep the config in `pubspec.yaml` (`unified_ads:` section), generate the asset, and load it:
   ```sh
   dart run unified_ads:generate_config   # writes assets/ads_config.json
   ```
   ```dart
   final config = (await AdConfigLoader.fromAsset('assets/ads_config.json')).valueOrNull!;
   ```
   The schema matches `AdConfig` one to one; see the [`unified_ads` README](packages/unified_ads/README.md#declarative-config).
5. Show ads:
   ```dart
   final rewarded = RewardedAd(onEarnedReward: (ad, reward) => grant(reward.amount));
   if ((await rewarded.load()).isSuccess) await rewarded.show();

   final banner = BannerAd(size: const BannerSize.adaptiveAnchored());
   // in build(): UnifiedBannerWidget(ad: banner, anchored: true)
   ```

> Android **minSdk 24** · iOS **13.0** (**15.0** with `unified_ads_facebook`) · Flutter 3.44+ / Dart 3.12+.
> Don't enable Unity Ads and LevelPlay together: the Unity SDK initializes once per process, so unified_ads skips Unity.

## Example app: try every network in one screen

[`example/`](example) is a full test bench. It initializes every enabled network and has **one card per network** (plus
a "Waterfall (auto)" card) with **Banner**, **Load/Show interstitial** and **Load/Show rewarded** buttons. Ads appear
right on that screen. A **Settings** tab lets you enable networks and paste your own IDs (saved and re-initialized), and a
**Log** tab shows every callback with timestamps.

```sh
cd example
flutter run
```

It starts with public test credentials. AdMob, Facebook (banner + interstitial), Unity Ads and Start.io serve test ads
immediately; InMobi initializes but returns no-fill; AppLovin MAX and LevelPlay need your own keys. Full guide:
[example/README.md](example/README.md).

## Documentation

- [docs/getting_ids.md](docs/getting_ids.md): how to create the account, app and every ID for each network
- [docs/setup/](docs/setup): per-network platform setup
- [docs/consent_and_att.md](docs/consent_and_att.md): GDPR/US privacy/COPPA consent, other CMPs, and ATT
- [ARCHITECTURE.md](ARCHITECTURE.md): design, the adapter contract, and how opt-in linking works
- [SDK_STATUS.md](SDK_STATUS.md): verified SDK versions, deprecations, API names
- [docs/single_package_mode.md](docs/single_package_mode.md): the alternative build-flag mode (design and trade-offs)
- [docs/migration/](docs/migration): migration notes for public API changes
- [IMPLEMENTATION.md](IMPLEMENTATION.md): roadmap and progress
- [CONTRIBUTING.md](CONTRIBUTING.md): development setup and rules

## Development

```sh
flutter pub get
dart run melos run format       # dart format --set-exit-if-changed
dart run melos run analyze      # --fatal-infos, every package
dart run melos run test         # Dart unit + widget tests
dart run melos run build:example && dart run melos run test:kotlin
dart run melos run verify:opt-in   # AdMob + Unity + InMobi app links only those SDKs
```

CI ([`.github/workflows/ci.yaml`](.github/workflows/ci.yaml)) runs all of these, plus:

- the iOS build matrix (SPM, CocoaPods dynamic, CocoaPods static);
- the iOS opt-in check;
- a publish dry-run per package;
- pana.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT, see [LICENSE](LICENSE).
