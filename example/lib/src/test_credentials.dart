import 'package:unified_ads/unified_ads.dart';

/// Public **test / demo** credentials, used as the example app's defaults.
///
/// They live only in this example app, never in the packages. Each one is
/// documented in `docs/getting_ids.md` ("Testing without your own IDs"). Values
/// with no known public iOS equivalent are `null` on iOS: enter your own in
/// Settings.
abstract final class TestCredentials {
  /// Google's AdMob demo App ID and ad units: they always serve test ads.
  static final NetworkConfig admob = NetworkConfig(
    appId: PlatformValue.select(
      android: 'ca-app-pub-3940256099942544~3347511713',
      ios: 'ca-app-pub-3940256099942544~1458002511',
    ),
    bannerAdUnitId: PlatformValue.select(
      android: 'ca-app-pub-3940256099942544/9214589741',
      ios: 'ca-app-pub-3940256099942544/2435281174',
    ),
    interstitialAdUnitId: PlatformValue.select(
      android: 'ca-app-pub-3940256099942544/1033173712',
      ios: 'ca-app-pub-3940256099942544/4411468910',
    ),
    rewardedAdUnitId: PlatformValue.select(
      android: 'ca-app-pub-3940256099942544/5224354917',
      ios: 'ca-app-pub-3940256099942544/1712485313',
    ),
    rewardedInterstitialAdUnitId: PlatformValue.select(
      android: 'ca-app-pub-3940256099942544/5354046379',
      ios: 'ca-app-pub-3940256099942544/6978759866',
    ),
    appOpenAdUnitId: PlatformValue.select(
      android: 'ca-app-pub-3940256099942544/9257395921',
      ios: 'ca-app-pub-3940256099942544/5575463023',
    ),
  );

  /// Facebook Audience Network test placements (`IMG_16_9_APP_INSTALL#`
  /// prefix) from the `facebook_audience_network` plugin's example. There is
  /// no public rewarded placement.
  static final NetworkConfig facebook = NetworkConfig(
    bannerAdUnitId: _android(
      'IMG_16_9_APP_INSTALL#2312433698835503_2964944860251047',
    ),
    interstitialAdUnitId: _android(
      'IMG_16_9_APP_INSTALL#2312433698835503_2650502525028617',
    ),
  );

  /// Unity's sample game 14851. It has no interstitial placement, so the
  /// full-screen `rewardedVideo` placement is used for interstitials too.
  static final NetworkConfig unity = NetworkConfig(
    appId: _android('14851'),
    bannerAdUnitId: _android('bannerads'),
    interstitialAdUnitId: _android('rewardedVideo'),
    rewardedAdUnitId: _android('rewardedVideo'),
  );

  /// Start.io's demo App ID; Start.io needs no ad-unit IDs.
  static final NetworkConfig startapp = NetworkConfig(
    appId: _android('205489527'),
  );

  /// InMobi's sample account and placements. They initialize but usually
  /// return no fill outside InMobi's own sample app.
  static final NetworkConfig inmobi = NetworkConfig(
    appId: _android('8ba05e170e914971a0b45d977809a6cf'),
    bannerAdUnitId: _android('1651462467602'),
    interstitialAdUnitId: _android('1476878485960'),
    rewardedAdUnitId: _android('1623469928141'),
  );

  /// LevelPlay's official demo app key and ad units. Disabled by default:
  /// LevelPlay and Unity Ads cannot run in the same app (A11), and the demo
  /// key does not fill outside the vendor's demo app.
  static final NetworkConfig ironsource = NetworkConfig(
    enabled: false,
    appId: _android('25b63cf85'),
    bannerAdUnitId: _android('4fpetq4lhe5lsw3e'),
    interstitialAdUnitId: _android('h3xw38h9214adgxo'),
    rewardedAdUnitId: _android('syz3d8ekts22q0or'),
  );

  /// AppLovin MAX publishes no test SDK key: enter yours in Settings.
  static const NetworkConfig applovin = NetworkConfig(enabled: false);

  /// The example's default configuration: every network, test mode on.
  static AdConfig defaults() => AdConfig(
    testMode: true,
    waterfall: const [
      AdNetwork.admob,
      AdNetwork.facebook,
      AdNetwork.unity,
      AdNetwork.startapp,
      AdNetwork.inmobi,
      AdNetwork.applovin,
      AdNetwork.ironsource,
    ],
    networks: {
      AdNetwork.admob: admob,
      AdNetwork.facebook: facebook,
      AdNetwork.unity: unity,
      AdNetwork.startapp: startapp,
      AdNetwork.inmobi: inmobi,
      AdNetwork.applovin: applovin,
      AdNetwork.ironsource: ironsource,
    },
  );

  static String? _android(String value) =>
      PlatformValue.select<String?>(android: value, ios: null);
}
