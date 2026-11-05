import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:unified_ads/unified_ads.dart';

import 'event_log.dart';

/// Builds the plain-text diagnostics report that the Log tab's "Copy
/// diagnostics" button puts on the clipboard. Community testers paste it into
/// a "Device verification" issue (SDK_STATUS.md).
///
/// Ad-unit and app IDs are NOT included, only whether each is set.
/// [maxEvents] limits how many of the newest log entries are included.
String buildDiagnosticsReport(
  EventLog log, {
  AdConfig? config,
  InitResult? initResult,
  int maxEvents = 200,
  DateTime? now,
}) {
  final buffer = StringBuffer()
    ..writeln('unified_ads diagnostics')
    ..writeln('generated: ${(now ?? DateTime.now()).toIso8601String()}')
    ..writeln('platform: ${_platform()}')
    ..writeln('dart: ${_dartVersion()}')
    ..writeln(
      'mode: ${kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug')}',
    )
    ..writeln()
    ..writeln('initialized: ${UnifiedAds.isInitialized}')
    ..writeln('init result: ${initResult ?? 'none'}');
  if (initResult != null) {
    for (final MapEntry(:key, :value) in {
      ...initResult.failed,
      ...initResult.skipped,
    }.entries) {
      buffer.writeln(
        '  ${key.id}: ${value.code.name}'
        '${value.nativeCode == null ? '' : ' (native ${value.nativeCode})'}'
        ': ${value.message}',
      );
    }
  }
  if (config != null) {
    buffer
      ..writeln('test mode: ${config.testMode}')
      ..writeln(
        'waterfall: ${config.effectiveWaterfall.map((n) => n.id).join(', ')}',
      );
    for (final MapEntry(:key, :value) in config.networks.entries) {
      String set(String? id) => id == null || id.isEmpty ? '-' : 'set';
      buffer.writeln(
        '  ${key.id}: enabled=${value.enabled} '
        'testMode=${config.isTestMode(key)} appId=${set(value.appId)} '
        'banner=${set(value.bannerAdUnitId)} '
        'interstitial=${set(value.interstitialAdUnitId)} '
        'rewarded=${set(value.rewardedAdUnitId)}',
      );
    }
  }
  final entries = log.entries.take(maxEvents).toList();
  buffer
    ..writeln()
    ..writeln(
      'events (newest first, ${entries.length} of '
      '${log.entries.length}):',
    );
  for (final e in entries) {
    final where = [
      if (e.network != null) e.network!.id,
      if (e.format != null) e.format!.id,
    ].join('/');
    buffer.writeln(
      '${e.timestamp} ${e.isError ? 'ERROR ' : ''}${e.kind}'
      '${where.isEmpty ? '' : ' [$where]'} ${e.message}',
    );
  }
  return buffer.toString();
}

String _platform() {
  if (kIsWeb) return 'web';
  return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
}

String _dartVersion() => kIsWeb ? 'web' : Platform.version.split(' ').first;
