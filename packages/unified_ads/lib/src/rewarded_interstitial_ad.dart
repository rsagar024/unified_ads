import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'full_screen_ad.dart';
import 'guard.dart';

/// Callback receiving a rewarded interstitial ad and the earned reward.
typedef RewardedInterstitialCallback =
    void Function(RewardedInterstitialAd ad, RewardItem reward);

/// A full-screen rewarded interstitial ad served through the waterfall.
///
/// Unlike `RewardedAd`, it can be shown at natural transitions without the
/// user opting in first; Google's policy requires an intro screen that lets
/// the user skip it. Networks without this format are skipped by the
/// waterfall (supported today: AdMob).
///
/// ```dart
/// final ad = RewardedInterstitialAd(
///   onEarnedReward: (ad, reward) => grant(reward.amount),
/// );
/// if ((await ad.load()).isSuccess) await ad.show();
/// ```
class RewardedInterstitialAd extends FullScreenAd<RewardedInterstitialAd> {
  /// Creates a rewarded interstitial ad. Nothing is loaded until [load] is
  /// called.
  RewardedInterstitialAd({
    super.forceNetwork,
    this.onEarnedReward,
    super.onLoaded,
    super.onFailedToLoad,
    super.onShown,
    super.onFailedToShow,
    super.onImpression,
    super.onClicked,
    super.onClosed,
  }) : super(AdFormat.rewardedInterstitial);

  /// Called when the user earned the reward (before `onClosed`).
  final RewardedInterstitialCallback? onEarnedReward;

  RewardItem? _reward;

  /// The reward earned from the most recently shown ad, if any.
  RewardItem? get reward => _reward;

  @override
  void handleEarnedReward(RewardItem reward) {
    _reward = reward;
    safeCallback('onEarnedReward', () => onEarnedReward?.call(this, reward));
  }
}
