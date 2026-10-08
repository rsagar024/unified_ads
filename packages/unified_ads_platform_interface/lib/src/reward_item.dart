import 'package:flutter/foundation.dart';

/// A reward granted by a rewarded ad.
@immutable
class RewardItem {
  /// Creates a reward.
  const RewardItem({required this.amount, required this.type});

  /// Reward amount as configured in the network dashboard.
  final num amount;

  /// Reward type or label (for example `coins`). May be empty if the network
  /// does not report one.
  final String type;

  @override
  bool operator ==(Object other) =>
      other is RewardItem && other.amount == amount && other.type == type;

  @override
  int get hashCode => Object.hash(amount, type);

  @override
  String toString() => 'RewardItem($amount $type)';
}
