import 'ad_error.dart';
import 'ad_format.dart';
import 'ad_network.dart';
import 'reward_item.dart';

/// Base class of every ad lifecycle event.
///
/// Each event identifies the ad by [network] and [adId]. For full-screen ads
/// the id equals the ad handle's id; for banners it is the id the banner
/// assigned to the native view.
sealed class AdEvent {
  /// Creates an event. [timestamp] defaults to now.
  AdEvent({
    required this.network,
    required this.adId,
    required this.format,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// The network that emitted the event.
  final AdNetwork network;

  /// Identifier of the ad the event belongs to.
  final String adId;

  /// The ad's format.
  final AdFormat format;

  /// When the event happened.
  final DateTime timestamp;

  /// Short event name, for logs (for example `loaded`).
  String get kind;

  @override
  String toString() => 'AdEvent.$kind(${network.id}/${format.id}#$adId)';
}

/// The ad loaded successfully.
final class AdLoaded extends AdEvent {
  /// Creates the event.
  AdLoaded({
    required super.network,
    required super.adId,
    required super.format,
    super.timestamp,
  });

  @override
  String get kind => 'loaded';
}

/// The ad failed to load.
final class AdFailedToLoad extends AdEvent {
  /// Creates the event.
  AdFailedToLoad({
    required super.network,
    required super.adId,
    required super.format,
    required this.error,
    super.timestamp,
  });

  /// Why loading failed.
  final AdError error;

  @override
  String get kind => 'failedToLoad';
}

/// The ad failed to show.
final class AdFailedToShow extends AdEvent {
  /// Creates the event.
  AdFailedToShow({
    required super.network,
    required super.adId,
    required super.format,
    required this.error,
    super.timestamp,
  });

  /// Why showing failed.
  final AdError error;

  @override
  String get kind => 'failedToShow';
}

/// The full-screen ad was presented.
final class AdShown extends AdEvent {
  /// Creates the event.
  AdShown({
    required super.network,
    required super.adId,
    required super.format,
    super.timestamp,
  });

  @override
  String get kind => 'shown';
}

/// The network recorded an impression.
final class AdImpression extends AdEvent {
  /// Creates the event.
  AdImpression({
    required super.network,
    required super.adId,
    required super.format,
    super.timestamp,
  });

  @override
  String get kind => 'impression';
}

/// The user clicked the ad.
final class AdClicked extends AdEvent {
  /// Creates the event.
  AdClicked({
    required super.network,
    required super.adId,
    required super.format,
    super.timestamp,
  });

  @override
  String get kind => 'clicked';
}

/// The full-screen ad was dismissed.
final class AdClosed extends AdEvent {
  /// Creates the event.
  AdClosed({
    required super.network,
    required super.adId,
    required super.format,
    super.timestamp,
  });

  @override
  String get kind => 'closed';
}

/// The user earned the reward of a rewarded ad.
final class AdEarnedReward extends AdEvent {
  /// Creates the event.
  AdEarnedReward({
    required super.network,
    required super.adId,
    required super.format,
    required this.reward,
    super.timestamp,
  });

  /// The earned reward.
  final RewardItem reward;

  @override
  String get kind => 'earnedReward';
}

/// A banner resolved its actual size (logical pixels).
final class BannerSized extends AdEvent {
  /// Creates the event.
  BannerSized({
    required super.network,
    required super.adId,
    required this.width,
    required this.height,
    super.timestamp,
  }) : super(format: AdFormat.banner);

  /// Resolved width in logical pixels.
  final double width;

  /// Resolved height in logical pixels.
  final double height;

  @override
  String get kind => 'bannerSized';
}
