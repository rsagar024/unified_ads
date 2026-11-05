import 'package:flutter/foundation.dart';

/// Timing rules for a full-screen format, applied on top of any
/// `FrequencyCap`.
///
/// `show()` fails with `AdErrorCode.frequencyCapped` (without contacting the
/// network) while any rule is not met:
///
/// * [initialDelay]: no show until this long after the first
///   `UnifiedAds.init` of the app process.
/// * [minInterval]: the cooldown between two shows of the format.
/// * [showEveryActions]: at least this many `UnifiedAds.recordAction()` calls
///   since the previous show of the format.
///
/// ```dart
/// AdConfig(
///   pacing: {
///     AdFormat.interstitial: AdPacing(
///       initialDelay: Duration(seconds: 30),
///       minInterval: Duration(seconds: 15),
///       showEveryActions: 3,
///     ),
///   },
/// )
/// ```
@immutable
class AdPacing {
  /// Creates pacing rules. Durations must not be negative and
  /// [showEveryActions] must be at least 1.
  const AdPacing({
    this.minInterval = Duration.zero,
    this.showEveryActions = 1,
    this.initialDelay = Duration.zero,
  });

  /// Minimum time between two shows of the format.
  final Duration minInterval;

  /// Minimum number of recorded actions since the previous show of the
  /// format (or since the app started counting, for the first show).
  ///
  /// `1` (the default) disables action pacing.
  final int showEveryActions;

  /// Minimum time after the first `UnifiedAds.init` before the format may be
  /// shown.
  final Duration initialDelay;

  /// Whether action pacing is enabled.
  bool get usesActions => showEveryActions > 1;

  @override
  bool operator ==(Object other) =>
      other is AdPacing &&
      other.minInterval == minInterval &&
      other.showEveryActions == showEveryActions &&
      other.initialDelay == initialDelay;

  @override
  int get hashCode => Object.hash(minInterval, showEveryActions, initialDelay);

  @override
  String toString() =>
      'AdPacing(minInterval: $minInterval, showEveryActions: '
      '$showEveryActions, initialDelay: $initialDelay)';
}
