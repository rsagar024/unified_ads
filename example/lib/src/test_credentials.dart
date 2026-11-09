import 'package:unified_ads/unified_ads.dart';

/// Placeholder credentials for the example app.
///
/// Every value below is a **placeholder** that you must replace with your own
/// IDs from each ad network's dashboard before building a release. Leaving
/// placeholders in place means the example will initialize but will not receive
/// real fill — and will not attribute revenue to any demo/vendor account.
///
/// **Never copy these placeholder values into a production app.** They are
/// intentionally invalid. See `doc/getting_ids.md` for how to obtain real IDs
/// per network, and the Settings tab of this example to enter them at runtime.
///
/// The former public demo IDs (AdMob `ca-app-pub-3940256099942544~…`, Unity
/// game `14851`, Start.io `205489527`, InMobi `8ba05e170e914971a0b45d977809a6cf`,
/// Facebook `IMG_16_9_APP_INSTALL#…` placements, LevelPlay demo key
/// `25b63cf85`) have been removed. CI smoke tests that need real test IDs use
/// `example/integration_test/smoke_ids.dart` instead; that file is CI-only and
/// is not part of the example app's default configuration.
abstract final class TestCredentials {
  /// AdMob: replace with your AdMob App ID and ad unit IDs from the AdMob UI.
  static final NetworkConfig admob = NetworkConfig(
    appId: PlatformValue.select(
      android: 'YOUR_ADMOB_APP_ID_ANDROID',
      ios: 'YOUR_ADMOB_APP_ID_IOS',
    ),
    bannerAdUnitId: PlatformValue.select(
      android: 'YOUR_ADMOB_BANNER_AD_UNIT_ID_ANDROID',
      ios: 'YOUR_ADMOB_BANNER_AD_UNIT_ID_IOS',
    ),
    interstitialAdUnitId: PlatformValue.select(
      android: 'YOUR_ADMOB_INTERSTITIAL_AD_UNIT_ID_ANDROID',
      ios: 'YOUR_ADMOB_INTERSTITIAL_AD_UNIT_ID_IOS',
    ),
    rewardedAdUnitId: PlatformValue.select(
      android: 'YOUR_ADMOB_REWARDED_AD_UNIT_ID_ANDROID',
      ios: 'YOUR_ADMOB_REWARDED_AD_UNIT_ID_IOS',
    ),
    rewardedInterstitialAdUnitId: PlatformValue.select(
      android: 'YOUR_ADMOB_REWARDED_INTERSTITIAL_AD_UNIT_ID_ANDROID',
      ios: 'YOUR_ADMOB_REWARDED_INTERSTITIAL_AD_UNIT_ID_IOS',
    ),
    appOpenAdUnitId: PlatformValue.select(
      android: 'YOUR_ADMOB_APP_OPEN_AD_UNIT_ID_ANDROID',
      ios: 'YOUR_ADMOB_APP_OPEN_AD_UNIT_ID_IOS',
    ),
  );

  /// Facebook Audience Network: replace with your Meta placement IDs.
  /// There is no public rewarded placement.
  static final NetworkConfig facebook = NetworkConfig(
    bannerAdUnitId: _android('YOUR_FACEBOOK_BANNER_PLACEMENT_ID'),
    interstitialAdUnitId: _android('YOUR_FACEBOOK_INTERSTITIAL_PLACEMENT_ID'),
  );

  /// Unity Ads: replace with your Unity Game ID and placement IDs from
  /// cloud.unity.com. Unity Ads and LevelPlay cannot run in the same app.
  static final NetworkConfig unity = NetworkConfig(
    appId: _android('YOUR_UNITY_GAME_ID'),
    bannerAdUnitId: _android('YOUR_UNITY_BANNER_PLACEMENT_ID'),
    interstitialAdUnitId: _android('YOUR_UNITY_INTERSTITIAL_PLACEMENT_ID'),
    rewardedAdUnitId: _android('YOUR_UNITY_REWARDED_PLACEMENT_ID'),
  );

  /// Start.io: replace with your Start.io App ID from portal.start.io.
  /// Start.io needs no per-format ad-unit IDs.
  static final NetworkConfig startapp = NetworkConfig(
    appId: _android('YOUR_STARTIO_APP_ID'),
  );

  /// InMobi: replace with your InMobi Account ID and numeric placement IDs
  /// from publisher.inmobi.com.
  static final NetworkConfig inmobi = NetworkConfig(
    appId: _android('YOUR_INMOBI_ACCOUNT_ID'),
    bannerAdUnitId: _android('YOUR_INMOBI_BANNER_PLACEMENT_ID'),
    interstitialAdUnitId: _android('YOUR_INMOBI_INTERSTITIAL_PLACEMENT_ID'),
    rewardedAdUnitId: _android('YOUR_INMOBI_REWARDED_PLACEMENT_ID'),
  );

  /// LevelPlay: replace with your LevelPlay App Key and ad units from
  /// platform.ironsrc.com. Disabled by default: LevelPlay and Unity Ads cannot
  /// run in the same app (A11).
  static final NetworkConfig ironsource = NetworkConfig(
    enabled: false,
    appId: _android('YOUR_LEVELPLAY_APP_KEY'),
    bannerAdUnitId: _android('YOUR_LEVELPLAY_BANNER_PLACEMENT_ID'),
    interstitialAdUnitId: _android('YOUR_LEVELPLAY_INTERSTITIAL_PLACEMENT_ID'),
    rewardedAdUnitId: _android('YOUR_LEVELPLAY_REWARDED_PLACEMENT_ID'),
  );

  /// AppLovin MAX: no public test SDK key exists. Enter your SDK key in
  /// Settings, then enable the network.
  static const NetworkConfig applovin = NetworkConfig(enabled: false);

  /// The example's default configuration: every network listed, test mode on,
  /// but all IDs are placeholders — replace them before release.
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
