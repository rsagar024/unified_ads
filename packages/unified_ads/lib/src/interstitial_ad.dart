import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'full_screen_ad.dart';

/// A full-screen interstitial ad served through the waterfall.
///
/// ```dart
/// final ad = InterstitialAd(onClosed: (ad) => print('closed, served by ${ad.servedBy}'));
/// if ((await ad.load()).isSuccess) await ad.show();
/// ```
class InterstitialAd extends FullScreenAd<InterstitialAd> {
  /// Creates an interstitial ad. Nothing is loaded until [load] is called.
  InterstitialAd({
    super.forceNetwork,
    super.onLoaded,
    super.onFailedToLoad,
    super.onShown,
    super.onFailedToShow,
    super.onImpression,
    super.onClicked,
    super.onClosed,
  }) : super(AdFormat.interstitial);
}
