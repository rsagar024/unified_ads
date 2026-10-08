import 'package:flutter/foundation.dart';

import 'ad_network.dart';

/// Log severity, from most to least verbose. [none] disables logging.
enum AdsLogLevel {
  /// Very detailed tracing.
  verbose,

  /// Debugging information.
  debug,

  /// Notable lifecycle events.
  info,

  /// Recoverable problems.
  warning,

  /// Failures.
  error,

  /// Logging disabled.
  none,
}

/// A single log entry.
@immutable
class AdsLogRecord {
  /// Creates a record.
  const AdsLogRecord({
    required this.level,
    required this.message,
    required this.time,
    this.network,
    this.error,
    this.stackTrace,
  });

  /// Severity.
  final AdsLogLevel level;

  /// Log message.
  final String message;

  /// When the record was created.
  final DateTime time;

  /// Related network, if any.
  final AdNetwork? network;

  /// Related error object, if any.
  final Object? error;

  /// Stack trace of [error], if any.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final net = network == null ? '' : '[${network!.id}] ';
    final err = error == null ? '' : ' ($error)';
    return '[unified_ads] ${level.name.toUpperCase()} $net$message$err';
  }
}

/// Receives log records.
typedef AdsLogSink = void Function(AdsLogRecord record);

/// Pluggable logger. Silent by default.
///
/// ```dart
/// UnifiedAds.logger = AdsLogger.console(level: AdsLogLevel.debug);
/// UnifiedAds.logger = AdsLogger(level: AdsLogLevel.warning, sink: myCrashlyticsSink);
/// ```
@immutable
class AdsLogger {
  /// Creates a logger that forwards records at or above [level] to [sink].
  const AdsLogger({this.level = AdsLogLevel.none, this.sink});

  /// A logger that prints to the debug console via [debugPrint].
  const AdsLogger.console({AdsLogLevel level = AdsLogLevel.debug})
    : this(level: level, sink: _consoleSink);

  /// A logger that discards everything.
  static const silent = AdsLogger();

  /// The logger used by unified_ads and its adapters. Set it through
  /// `UnifiedAds.logger`.
  static AdsLogger current = silent;

  /// Minimum level that is forwarded.
  final AdsLogLevel level;

  /// Destination of records; `null` discards them.
  final AdsLogSink? sink;

  /// Whether records at [level] are forwarded.
  bool isEnabled(AdsLogLevel level) =>
      sink != null &&
      level != AdsLogLevel.none &&
      this.level != AdsLogLevel.none &&
      level.index >= this.level.index;

  /// Logs [message] at [level]. Sink exceptions are swallowed.
  void log(
    AdsLogLevel level,
    String message, {
    AdNetwork? network,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!isEnabled(level)) return;
    try {
      sink!(
        AdsLogRecord(
          level: level,
          message: message,
          time: DateTime.now(),
          network: network,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (_) {
      // A broken sink must never affect ad delivery.
    }
  }

  /// Logs at [AdsLogLevel.verbose].
  void verbose(String message, {AdNetwork? network}) =>
      log(AdsLogLevel.verbose, message, network: network);

  /// Logs at [AdsLogLevel.debug].
  void debug(String message, {AdNetwork? network}) =>
      log(AdsLogLevel.debug, message, network: network);

  /// Logs at [AdsLogLevel.info].
  void info(String message, {AdNetwork? network}) =>
      log(AdsLogLevel.info, message, network: network);

  /// Logs at [AdsLogLevel.warning].
  void warning(String message, {AdNetwork? network, Object? error}) =>
      log(AdsLogLevel.warning, message, network: network, error: error);

  /// Logs at [AdsLogLevel.error].
  void error(
    String message, {
    AdNetwork? network,
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    AdsLogLevel.error,
    message,
    network: network,
    error: error,
    stackTrace: stackTrace,
  );

  static void _consoleSink(AdsLogRecord record) {
    debugPrint(record.toString());
    if (record.stackTrace != null) debugPrint(record.stackTrace.toString());
  }
}

/// Masks an ad-unit or app ID for logging, keeping the first and last four
/// characters (`ca-a…3713`).
String maskId(String? id) {
  if (id == null || id.isEmpty) return '<none>';
  if (id.length <= 8) return '****';
  return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
}
