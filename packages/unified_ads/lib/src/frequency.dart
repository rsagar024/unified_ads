import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

/// Persists show timestamps used for frequency capping.
///
/// The default [InMemoryFrequencyStore] forgets everything when the app
/// restarts. Implement this interface (for example on top of
/// shared_preferences) to keep caps across launches.
abstract class FrequencyStore {
  /// Allows subclasses to have `const` constructors.
  const FrequencyStore();

  /// Returns the stored show timestamps for [format].
  Future<List<DateTime>> read(AdFormat format);

  /// Replaces the stored show timestamps for [format].
  Future<void> write(AdFormat format, List<DateTime> shows);
}

/// A [FrequencyStore] that keeps timestamps in memory only.
class InMemoryFrequencyStore extends FrequencyStore {
  /// Creates an empty store.
  InMemoryFrequencyStore();

  final Map<AdFormat, List<DateTime>> _shows = {};

  @override
  Future<List<DateTime>> read(AdFormat format) async =>
      List.of(_shows[format] ?? const <DateTime>[]);

  @override
  Future<void> write(AdFormat format, List<DateTime> shows) async {
    _shows[format] = List.of(shows);
  }
}

/// Applies [FrequencyCap]s using a sliding window.
class FrequencyLimiter {
  /// Creates a limiter.
  FrequencyLimiter({
    required this.caps,
    required this.store,
    required this.now,
  });

  /// Caps per format.
  final Map<AdFormat, FrequencyCap> caps;

  /// Timestamp storage.
  final FrequencyStore store;

  /// Clock.
  final DateTime Function() now;

  /// Whether [format] may be shown now.
  Future<bool> canShow(AdFormat format) async {
    final cap = caps[format];
    if (cap == null) return true;
    final shows = await _recent(format, cap);
    return shows.length < cap.maxShows;
  }

  /// Records a show of [format] now.
  Future<void> record(AdFormat format) async {
    final cap = caps[format];
    if (cap == null) return;
    final shows = await _recent(format, cap);
    await store.write(format, [...shows, now()]);
  }

  Future<List<DateTime>> _recent(AdFormat format, FrequencyCap cap) async {
    final windowStart = now().subtract(cap.per);
    final shows = await store.read(format);
    return shows.where((t) => t.isAfter(windowStart)).toList();
  }
}
