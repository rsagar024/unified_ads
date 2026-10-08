import 'package:flutter/foundation.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

/// Outcome of `UnifiedAds.init`.
@immutable
class InitResult {
  /// Creates a result.
  const InitResult({
    this.ready = const {},
    this.failed = const {},
    this.skipped = const {},
    this.error,
  });

  /// Networks whose SDK initialized and that can serve ads.
  final Set<AdNetwork> ready;

  /// Networks whose SDK initialization failed or timed out.
  final Map<AdNetwork, AdError> failed;

  /// Networks that were not initialized: disabled, adapter missing, invalid
  /// per-network configuration or a conflict.
  final Map<AdNetwork, AdError> skipped;

  /// Set when the configuration as a whole is invalid; nothing was
  /// initialized.
  final AdError? error;

  /// Whether at least one network is ready and the configuration is valid.
  bool get isSuccess => error == null && ready.isNotEmpty;

  @override
  String toString() =>
      'InitResult(ready: ${ready.map((n) => n.id).toList()}, '
      'failed: ${failed.keys.map((n) => n.id).toList()}, '
      'skipped: ${skipped.keys.map((n) => n.id).toList()}'
      '${error == null ? '' : ', error: $error'})';
}
