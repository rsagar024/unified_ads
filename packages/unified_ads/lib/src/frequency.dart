import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

/// Persists show timestamps used for frequency capping and pacing, and the
/// action counter used by `AdPacing.showEveryActions`.
///
/// The default [InMemoryFrequencyStore] forgets everything when the app
/// restarts. For production use, pass a persistent store such as
/// [SharedPreferencesFrequencyStore] to `UnifiedAds.init` so that frequency
/// caps and pacing survive app restarts. Without a persistent store, a user
/// can bypass frequency limits by killing and relaunching the app.
///
/// ```dart
/// await UnifiedAds.init(
///   config,
///   frequencyStore: SharedPreferencesFrequencyStore(),
/// );
/// ```
///
/// The action-counter methods have default bodies that persist nothing, so
/// stores written for unified_ads 1.0 keep working when they `extend` this
/// class; override them to persist the counter too.
abstract class FrequencyStore {
  /// Allows subclasses to have `const` constructors.
  const FrequencyStore();

  /// Returns the stored show timestamps for [format].
  Future<List<DateTime>> read(AdFormat format);

  /// Replaces the stored show timestamps for [format].
  Future<void> write(AdFormat format, List<DateTime> shows);

  /// Returns the stored action count, or `null` when none is stored.
  Future<int?> readActionCount() async => null;

  /// Stores the action count.
  Future<void> writeActionCount(int count) async {}

  /// Returns the action count at the last show of [format], or `null`.
  Future<int?> readActionMark(AdFormat format) async => null;

  /// Stores the action count at the last show of [format].
  Future<void> writeActionMark(AdFormat format, int count) async {}
}

/// A [FrequencyStore] that keeps everything in memory only.
class InMemoryFrequencyStore extends FrequencyStore {
  /// Creates an empty store.
  InMemoryFrequencyStore();

  final Map<AdFormat, List<DateTime>> _shows = {};
  final Map<AdFormat, int> _marks = {};
  int? _actions;

  @override
  Future<List<DateTime>> read(AdFormat format) async =>
      List.of(_shows[format] ?? const <DateTime>[]);

  @override
  Future<void> write(AdFormat format, List<DateTime> shows) async {
    _shows[format] = List.of(shows);
  }

  @override
  Future<int?> readActionCount() async => _actions;

  @override
  Future<void> writeActionCount(int count) async => _actions = count;

  @override
  Future<int?> readActionMark(AdFormat format) async => _marks[format];

  @override
  Future<void> writeActionMark(AdFormat format, int count) async =>
      _marks[format] = count;
}

/// A [FrequencyStore] that persists data using `shared_preferences`, so
/// frequency caps and pacing survive app restarts.
///
/// Show timestamps, action count, and action marks are stored as
/// key/value pairs in `SharedPreferences`. Each format uses its own key
/// derived from `[AdFormat.id]`:
/// - `unified_ads_freq_${format.id}` → list of ISO-8601 timestamp strings
/// - `unified_ads_freq_action_count` → int
/// - `unified_ads_freq_action_mark_${format.id}` → int
///
/// **Important:** `SharedPreferences` writes are asynchronous and are not
/// guaranteed to be flushed to disk before the process is terminated. For
/// production apps that require strict frequency-cap enforcement across
/// restarts, consider wrapping this store or using a more durable storage
/// mechanism.
class SharedPreferencesFrequencyStore extends FrequencyStore {
  /// Creates a store backed by `_sharedPreferences`.
  ///
  /// If `_sharedPreferences` is omitted, the default instance from
  /// `SharedPreferences.getInstance()` is used lazily on first access.
  SharedPreferencesFrequencyStore({this._sharedPreferences});

  final SharedPreferences? _sharedPreferences;

  Future<SharedPreferences> _prefs() async {
    return _sharedPreferences ?? await SharedPreferences.getInstance();
  }

  static String _showsKey(AdFormat format) =>
      'unified_ads_freq_${format.id}';

  static String _actionCountKey() => 'unified_ads_freq_action_count';

  static String _actionMarkKey(AdFormat format) =>
      'unified_ads_freq_action_mark_${format.id}';

  @override
  Future<List<DateTime>> read(AdFormat format) async {
    final prefs = await _prefs();
    final strings = prefs.getStringList(_showsKey(format)) ?? <String>[];
    return strings
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList();
  }

  @override
  Future<void> write(AdFormat format, List<DateTime> shows) async {
    final prefs = await _prefs();
    await prefs.setStringList(
      _showsKey(format),
      shows.map((d) => d.toIso8601String()).toList(),
    );
  }

  @override
  Future<int?> readActionCount() async {
    final prefs = await _prefs();
    return prefs.getInt(_actionCountKey());
  }

  @override
  Future<void> writeActionCount(int count) async {
    final prefs = await _prefs();
    await prefs.setInt(_actionCountKey(), count);
  }

  @override
  Future<int?> readActionMark(AdFormat format) async {
    final prefs = await _prefs();
    return prefs.getInt(_actionMarkKey(format));
  }

  @override
  Future<void> writeActionMark(AdFormat format, int count) async {
    final prefs = await _prefs();
    await prefs.setInt(_actionMarkKey(format), count);
  }
}

/// The action counter behind `UnifiedAds.recordAction`. Lives in the runtime
/// so it survives re-initialization.
class ActionCounter {
  /// Current count.
  int count = 0;

  /// Count at the last show, per format.
  final Map<AdFormat, int> marks = {};

  /// Loads the values [store] has persisted, keeping in-memory values the
  /// store does not know.
  Future<void> restore(FrequencyStore store) async {
    count = await store.readActionCount() ?? count;
    for (final format in AdFormat.values.where((f) => f.isFullScreen)) {
      final mark = await store.readActionMark(format);
      if (mark != null) marks[format] = mark;
    }
  }

  /// Number of actions since the last show of [format].
  int since(AdFormat format) => count - (marks[format] ?? 0);
}

/// Applies [FrequencyCap]s (sliding window) and [AdPacing] rules.
class FrequencyLimiter {
  /// Creates a limiter.
  FrequencyLimiter({
    required this.caps,
    required this.store,
    required this.now,
    this.pacing = const {},
    DateTime? startedAt,
    ActionCounter? actions,
  }) : startedAt = startedAt ?? now(),
       actions = actions ?? ActionCounter();

  /// Caps per format.
  final Map<AdFormat, FrequencyCap> caps;

  /// Pacing rules per format.
  final Map<AdFormat, AdPacing> pacing;

  /// Timestamp storage.
  final FrequencyStore store;

  /// Clock.
  final DateTime Function() now;

  /// Start of `AdPacing.initialDelay`.
  final DateTime startedAt;

  /// Action counter for `AdPacing.showEveryActions`.
  final ActionCounter actions;

  /// Whether [format] may be shown now.
  Future<bool> canShow(AdFormat format) async =>
      await blockReason(format) == null;

  /// Why [format] may not be shown now, or `null` when it may.
  Future<String?> blockReason(AdFormat format) async {
    final cap = caps[format];
    final rules = pacing[format];
    if (cap == null && rules == null) return null;
    final shows = await store.read(format);
    final current = now();
    if (cap != null &&
        _within(shows, current.subtract(cap.per)).length >= cap.maxShows) {
      return '${format.id} frequency cap reached '
          '(${cap.maxShows} per ${cap.per})';
    }
    if (rules == null) return null;
    final readyAt = startedAt.add(rules.initialDelay);
    if (current.isBefore(readyAt)) {
      return '${format.id} initial delay: '
          '${readyAt.difference(current).inSeconds} s left';
    }
    if (shows.isNotEmpty) {
      final nextAt = shows.last.add(rules.minInterval);
      if (current.isBefore(nextAt)) {
        return '${format.id} cooldown: '
            '${nextAt.difference(current).inSeconds} s left';
      }
    }
    if (rules.usesActions) {
      final done = actions.since(format);
      if (done < rules.showEveryActions) {
        return '${format.id} needs ${rules.showEveryActions} actions '
            'between shows ($done so far)';
      }
    }
    return null;
  }

  /// Records a show of [format] now.
  Future<void> record(AdFormat format) async {
    if (caps[format] == null && pacing[format] == null) return;
    final shows = await _recent(format);
    await store.write(format, [...shows, now()]);
    if (pacing[format]?.usesActions ?? false) {
      actions.marks[format] = actions.count;
      await store.writeActionMark(format, actions.count);
    }
  }

  /// Show timestamps still relevant to a cap window or a cooldown.
  Future<List<DateTime>> _recent(AdFormat format) async {
    final window = math.max(
      caps[format]?.per.inMicroseconds ?? 0,
      pacing[format]?.minInterval.inMicroseconds ?? 0,
    );
    final shows = await store.read(format);
    return _within(shows, now().subtract(Duration(microseconds: window)));
  }

  static List<DateTime> _within(List<DateTime> shows, DateTime start) =>
      shows.where((t) => t.isAfter(start)).toList();
}
