import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'full_screen_ad.dart';
import 'guard.dart';

/// Callback receiving a rewarded ad and the earned reward.
typedef RewardCallback = void Function(RewardedAd ad, RewardItem reward);

/// A full-screen rewarded ad served through the waterfall.
///
/// ```dart
/// final ad = RewardedAd(onEarnedReward: (ad, reward) => grant(reward.amount));
/// if ((await ad.load()).isSuccess) await ad.show();
/// ```
class RewardedAd extends FullScreenAd<RewardedAd> {
  /// Creates a rewarded ad. Nothing is loaded until [load] is called.
  RewardedAd({
    super.forceNetwork,
    this.onEarnedReward,
    super.onLoaded,
    super.onFailedToLoad,
    super.onShown,
    super.onFailedToShow,
    super.onImpression,
    super.onClicked,
    super.onClosed,
  }) : super(AdFormat.rewarded);

  /// Called when the user earned the reward (before `onClosed`).
  final RewardCallback? onEarnedReward;

  RewardItem? _reward;

  /// The reward earned from the most recently shown ad, if any.
  RewardItem? get reward => _reward;

  @override
  void handleEarnedReward(RewardItem reward) {
    _reward = reward;
    safeCallback('onEarnedReward', () => onEarnedReward?.call(this, reward));
  }
}
