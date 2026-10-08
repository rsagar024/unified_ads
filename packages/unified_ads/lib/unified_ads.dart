/// One Dart API for banner, interstitial, rewarded, rewarded interstitial and
/// app open ads across AdMob, Unity Ads, AppLovin MAX, LevelPlay, Facebook
/// Audience Network, Start.io and InMobi.
///
/// Add `unified_ads` plus the adapter package of every network you want
/// (for example `unified_ads_admob`); only those SDKs are linked into the app.
///
/// ```dart
/// await UnifiedAds.init(AdConfig(
///   testMode: true,
///   waterfall: [AdNetwork.admob, AdNetwork.unity],
///   networks: {
///     AdNetwork.admob: NetworkConfig(appId: '…', interstitialAdUnitId: '…'),
///     AdNetwork.unity: NetworkConfig(appId: '…', interstitialAdUnitId: '…'),
///   },
/// ));
///
/// final ad = InterstitialAd(onClosed: (ad) => debugPrint('${ad.servedBy}'));
/// if ((await ad.load()).isSuccess) await ad.show();
/// ```
library;

export 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

export 'src/app_open_ad.dart' show AppOpenAd;
export 'src/banner_ad.dart' show BannerAd, BannerAdState, BannerAttempt;
export 'src/banner_widget.dart'
    show
        BannerPlatformViewBuilder,
        UnifiedBannerWidget,
        buildBannerPlatformView;
export 'src/config_loader.dart' show AdConfigLoader;
export 'src/frequency.dart' show FrequencyStore, InMemoryFrequencyStore;
export 'src/full_screen_ad.dart' show AdCallback, AdErrorCallback, FullScreenAd;
export 'src/init_result.dart' show InitResult;
export 'src/interstitial_ad.dart' show InterstitialAd;
export 'src/rewarded_ad.dart' show RewardCallback, RewardedAd;
export 'src/rewarded_interstitial_ad.dart'
    show RewardedInterstitialAd, RewardedInterstitialCallback;
export 'src/unified_ads.dart' show UnifiedAds;
