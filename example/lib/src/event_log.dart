import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:unified_ads/unified_ads.dart';

/// One line of the event console.
@immutable
class LogEntry {
  /// Creates an entry.
  const LogEntry({
    required this.time,
    required this.kind,
    required this.message,
    this.network,
    this.format,
    this.isError = false,
  });

  /// When it happened.
  final DateTime time;

  /// Event kind (`loaded`, `shown`, …) or an app step (`init`, `load`, …).
  final String kind;

  /// Human-readable details.
  final String message;

  /// The network involved, if any.
  final AdNetwork? network;

  /// The format involved, if any.
  final AdFormat? format;

  /// Whether this entry reports a failure.
  final bool isError;

  /// `HH:mm:ss.SSS`.
  String get timestamp {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}

/// The live event console: every [UnifiedAds.events] callback plus the app's
/// own steps (init results, load/show results).
class EventLog extends ChangeNotifier {
  /// Creates a log, optionally listening to [events].
  EventLog({Stream<AdEvent>? events, this.maxEntries = 500}) {
    _subscription = events?.listen(addEvent);
  }

  /// Oldest entries are dropped past this size.
  final int maxEntries;

  final List<LogEntry> _entries = [];
  StreamSubscription<AdEvent>? _subscription;

  /// Entries, newest first.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Records a native ad event.
  void addEvent(AdEvent event) {
    final (message, isError) = switch (event) {
      AdFailedToLoad(:final error) ||
      AdFailedToShow(:final error) => (_describe(error), true),
      AdEarnedReward(:final reward) => (
        'reward ${reward.amount} ${reward.type}',
        false,
      ),
      BannerSized(:final width, :final height) => (
        'size ${width}x$height',
        false,
      ),
      _ => ('ad ${event.adId}', false),
    };
    _add(
      LogEntry(
        time: event.timestamp,
        kind: event.kind,
        network: event.network,
        format: event.format,
        message: message,
        isError: isError,
      ),
    );
  }

  /// Records an app step.
  void add(
    String kind,
    String message, {
    AdNetwork? network,
    AdFormat? format,
    bool isError = false,
  }) {
    _add(
      LogEntry(
        time: DateTime.now(),
        kind: kind,
        message: message,
        network: network,
        format: format,
        isError: isError,
      ),
    );
  }

  /// Records an [AdError] as a failed app step.
  void addError(String kind, AdError error, {AdFormat? format}) => add(
    kind,
    _describe(error),
    network: error.network,
    format: format,
    isError: true,
  );

  /// Empties the log.
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void _add(LogEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) _entries.removeLast();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  static String _describe(AdError error) {
    final native = error.nativeCode == null ? '' : ' [${error.nativeCode}]';
    return '${error.code.name}$native: ${error.message}';
  }
}
