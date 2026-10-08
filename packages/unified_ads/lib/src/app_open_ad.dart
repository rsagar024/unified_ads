import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'full_screen_ad.dart';

/// A full-screen app open ad served through the waterfall, shown when the
/// user starts the app or brings it back to the foreground.
///
/// Networks without this format are skipped by the waterfall (supported
/// today: AdMob and AppLovin MAX). App open ads expire after about four
/// hours; the default `AdConfig.cacheTtl` (one hour) refreshes cached ones
/// well before that.
///
/// A typical integration preloads one and shows it on resume, but never over
/// another full-screen ad:
///
/// ```dart
/// final appOpen = AppOpenAd();
/// await appOpen.load();
/// final listener = AppLifecycleListener(
///   onResume: () async {
///     if (appOpen.isReady && !otherFullScreenAdShowing) {
///       await appOpen.show();
///     } else {
///       await appOpen.load();
///     }
///   },
/// );
/// // Dispose `listener` and `appOpen` with the owning widget.
/// ```
class AppOpenAd extends FullScreenAd<AppOpenAd> {
  /// Creates an app open ad. Nothing is loaded until [load] is called.
  AppOpenAd({
    super.forceNetwork,
    super.onLoaded,
    super.onFailedToLoad,
    super.onShown,
    super.onFailedToShow,
    super.onImpression,
    super.onClicked,
    super.onClosed,
  }) : super(AdFormat.appOpen);
}
