import 'package:flutter/foundation.dart';

import 'ad_network.dart';

/// Machine-readable category of an [AdError].
enum AdErrorCode {
  /// An API was used before `UnifiedAds.init` completed.
  notInitialized,

  /// The configuration is invalid; the message names the offending field.
  invalidConfig,

  /// Two enabled networks cannot run together (for example Unity Ads and
  /// LevelPlay), or a network cannot run under the current consent state.
  configConflict,

  /// The configuration enables a network whose adapter package is not
  /// installed.
  adapterMissing,

  /// The network SDK failed to initialize or timed out.
  initializationFailed,

  /// The network does not support the requested format.
  unsupportedFormat,

  /// The network cannot serve ads through this plugin (documented stub).
  unsupportedNetwork,

  /// The format is disabled in configuration.
  formatDisabled,

  /// The network is disabled in configuration.
  networkDisabled,

  /// No ad was available.
  noFill,

  /// Loading took longer than the configured timeout.
  timeout,

  /// A connectivity or server error reported by the SDK.
  networkError,

  /// `show` was called without a loaded, valid ad.
  notReady,

  /// `show` was called while another full-screen ad is visible.
  alreadyShowing,

  /// The frequency cap for the format was reached.
  frequencyCapped,

  /// The SDK reported that the ad could not be shown.
  showFailed,

  /// No foreground Activity / view controller was available.
  noActivity,

  /// An unexpected error. The original exception is kept in the message.
  internal,
}

/// The single error type surfaced by unified_ads.
///
/// Native exceptions, SDK error codes and adapter failures are all mapped to
/// an [AdError]; nothing else reaches the app.
@immutable
class AdError implements Exception {
  /// Creates an error.
  const AdError({
    required this.code,
    required this.message,
    this.network,
    this.nativeCode,
    this.attempts = const [],
  });

  /// Wraps an unexpected [exception] as an [AdErrorCode.internal] error.
  factory AdError.fromException(Object exception, {AdNetwork? network}) {
    if (exception is AdError) {
      return network == null || exception.network != null
          ? exception
          : exception.copyWith(network: network);
    }
    return AdError(
      code: AdErrorCode.internal,
      message: exception.toString(),
      network: network,
    );
  }

  /// Error category.
  final AdErrorCode code;

  /// Human-readable description.
  final String message;

  /// The network that produced the error, if any.
  final AdNetwork? network;

  /// The SDK's own error code, as a string, if available.
  final String? nativeCode;

  /// Per-network errors collected by a waterfall, in attempt order.
  final List<AdError> attempts;

  /// Returns a copy with the given fields replaced.
  AdError copyWith({
    AdErrorCode? code,
    String? message,
    AdNetwork? network,
    String? nativeCode,
    List<AdError>? attempts,
  }) {
    return AdError(
      code: code ?? this.code,
      message: message ?? this.message,
      network: network ?? this.network,
      nativeCode: nativeCode ?? this.nativeCode,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdError &&
      other.code == code &&
      other.message == message &&
      other.network == network &&
      other.nativeCode == nativeCode &&
      listEquals(other.attempts, attempts);

  @override
  int get hashCode =>
      Object.hash(code, message, network, nativeCode, Object.hashAll(attempts));

  @override
  String toString() {
    final buffer = StringBuffer('AdError(${code.name}');
    if (network != null) buffer.write(', ${network!.id}');
    if (nativeCode != null) buffer.write(', native: $nativeCode');
    buffer.write('): $message');
    for (final attempt in attempts) {
      buffer.write('\n  - $attempt');
    }
    return buffer.toString();
  }
}
