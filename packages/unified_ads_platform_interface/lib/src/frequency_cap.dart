import 'package:flutter/foundation.dart';

/// Limits how often a full-screen format may be shown: at most [maxShows]
/// shows within any sliding window of length [per].
@immutable
class FrequencyCap {
  /// Creates a cap. [maxShows] must be positive and [per] non-zero.
  const FrequencyCap({required this.maxShows, required this.per});

  /// Maximum number of shows inside the window.
  final int maxShows;

  /// Length of the sliding window.
  final Duration per;

  @override
  bool operator ==(Object other) =>
      other is FrequencyCap && other.maxShows == maxShows && other.per == per;

  @override
  int get hashCode => Object.hash(maxShows, per);

  @override
  String toString() => 'FrequencyCap($maxShows per $per)';
}
