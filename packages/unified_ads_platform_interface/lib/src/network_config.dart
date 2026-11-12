import 'package:flutter/foundation.dart';

import 'ad_format.dart';

/// Maximum number of entries allowed in [NetworkConfig.extras].
const configExtrasMaxEntries = 16;

/// Maximum length (in characters) for a string value in [NetworkConfig.extras].
const configExtrasMaxValueLength = 256;

/// Credentials and options for one ad network.
///
/// What [appId] means depends on the network: AdMob App ID, Unity Game ID,
/// AppLovin MAX SDK key, LevelPlay App Key, Start.io App ID or InMobi Account
/// ID. See each adapter's setup doc. Use `PlatformValue.select` for values that
/// differ per platform.
@immutable
class NetworkConfig {
  /// Creates a network configuration.
  ///
  /// [extras] must contain only JSON-safe primitives (`String`, `int`, `double`,
  /// `bool`, `List` of primitives, or `Map<String, Object?>` of primitives).
  /// Null values, non-primitive types, more than $configExtrasMaxEntries
  /// entries, or string values longer than $configExtrasMaxValueLength
  /// characters are not allowed. Use [validateExtras] to validate before
  /// construction when extras come from an untrusted source.
  const NetworkConfig({
    this.enabled = true,
    this.appId,
    this.bannerAdUnitId,
    this.interstitialAdUnitId,
    this.rewardedAdUnitId,
    this.rewardedInterstitialAdUnitId,
    this.appOpenAdUnitId,
    this.testMode,
    this.enabledFormats,
    this.requiredFormats,
    this.testDeviceIds = const [],
    this.extras = const {},
  });

  /// Whether the network takes part at all.
  final bool enabled;

  /// App-level identifier (see the class documentation).
  final String? appId;

  /// Banner ad-unit / placement ID.
  final String? bannerAdUnitId;

  /// Interstitial ad-unit / placement ID.
  final String? interstitialAdUnitId;

  /// Rewarded ad-unit / placement ID.
  final String? rewardedAdUnitId;

  /// Rewarded-interstitial ad-unit / placement ID.
  final String? rewardedInterstitialAdUnitId;

  /// App-open ad-unit / placement ID.
  final String? appOpenAdUnitId;

  /// Per-network test-mode override; `null` follows the global setting.
  final bool? testMode;

  /// Formats this network may serve; `null` means all supported formats.
  final Set<AdFormat>? enabledFormats;

  /// Formats for which at least one ad-unit ID is mandatory. When `null`,
  /// no ad-unit ID presence check is performed by the config validator. When
  /// set, at least one listed format must have a non-empty ad-unit ID,
  /// otherwise the network is skipped during initialization. Use this for
  /// networks that require at least one placement to be useful (for example
  /// AdMob, Unity, LevelPlay). Leave null for app-ID-only networks such as
  /// Start.io.
  final Set<AdFormat>? requiredFormats;

  /// Test device identifiers (AdMob test device IDs, AppLovin GAIDs, …).
  final List<String> testDeviceIds;

  /// Network-specific options, documented per adapter.
  ///
  /// Values must be JSON-safe primitives: `String`, `int`, `double`, `bool`,
  /// `List` of primitives, or `Map<String, Object?>` of primitives. Maximum
  /// $configExtrasMaxEntries entries; string values are limited to
  /// $configExtrasMaxValueLength characters. Validated when loaded from
  /// declarative config and when set via [copyWith].
  final Map<String, Object?> extras;

  /// Validates that [extras] contains only JSON-safe primitive values.
  ///
  /// Throws [ArgumentError] if [extras] contains disallowed types, too many
  /// entries, or values that are too large. Called by [copyWith] when an
  /// [extras] replacement is provided.
  static void validateExtras(Map<String, Object?> extras, String path) {
    if (extras.length > configExtrasMaxEntries) {
      throw ArgumentError(
        '$path: extras has ${extras.length} entries (max $configExtrasMaxEntries)',
      );
    }
    for (final MapEntry(key: key, value: value) in extras.entries) {
      if (key.isEmpty) {
        throw ArgumentError(
          '$path.$key: extras keys must be non-empty strings',
        );
      }
      _validateExtrasValue(value, '$path.$key');
    }
  }

  /// The ad-unit ID configured for [format], or `null`.
  String? adUnitIdFor(AdFormat format) => switch (format) {
    AdFormat.banner => bannerAdUnitId,
    AdFormat.interstitial => interstitialAdUnitId,
    AdFormat.rewarded => rewardedAdUnitId,
    AdFormat.rewardedInterstitial => rewardedInterstitialAdUnitId,
    AdFormat.appOpen => appOpenAdUnitId,
  };

  /// Whether [format] is enabled for this network.
  bool isFormatEnabled(AdFormat format) =>
      enabledFormats == null || enabledFormats!.contains(format);

  /// Returns a copy with the given fields replaced.
  NetworkConfig copyWith({
    bool? enabled,
    String? appId,
    String? bannerAdUnitId,
    String? interstitialAdUnitId,
    String? rewardedAdUnitId,
    String? rewardedInterstitialAdUnitId,
    String? appOpenAdUnitId,
    bool? testMode,
    Set<AdFormat>? enabledFormats,
    Set<AdFormat>? requiredFormats,
    List<String>? testDeviceIds,
    Map<String, Object?>? extras,
  }) {
    final resolvedExtras = extras ?? this.extras;
    // Validate replacement extras before constructing the copy, since these
    // cross the Dart/native boundary via Pigeon serialization.
    if (extras != null) {
      validateExtras(resolvedExtras, 'extras');
    }
    return NetworkConfig(
      enabled: enabled ?? this.enabled,
      appId: appId ?? this.appId,
      bannerAdUnitId: bannerAdUnitId ?? this.bannerAdUnitId,
      interstitialAdUnitId: interstitialAdUnitId ?? this.interstitialAdUnitId,
      rewardedAdUnitId: rewardedAdUnitId ?? this.rewardedAdUnitId,
      rewardedInterstitialAdUnitId:
          rewardedInterstitialAdUnitId ?? this.rewardedInterstitialAdUnitId,
      appOpenAdUnitId: appOpenAdUnitId ?? this.appOpenAdUnitId,
      testMode: testMode ?? this.testMode,
      enabledFormats: enabledFormats ?? this.enabledFormats,
      requiredFormats: requiredFormats ?? this.requiredFormats,
      testDeviceIds: testDeviceIds ?? this.testDeviceIds,
      extras: resolvedExtras,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NetworkConfig &&
      other.enabled == enabled &&
      other.appId == appId &&
      other.bannerAdUnitId == bannerAdUnitId &&
      other.interstitialAdUnitId == interstitialAdUnitId &&
      other.rewardedAdUnitId == rewardedAdUnitId &&
      other.rewardedInterstitialAdUnitId == rewardedInterstitialAdUnitId &&
      other.appOpenAdUnitId == appOpenAdUnitId &&
      other.testMode == testMode &&
      setEquals(other.enabledFormats, enabledFormats) &&
      setEquals(other.requiredFormats, requiredFormats) &&
      listEquals(other.testDeviceIds, testDeviceIds) &&
      mapEquals(other.extras, extras);

  @override
  int get hashCode => Object.hash(
    enabled,
    appId,
    bannerAdUnitId,
    interstitialAdUnitId,
    rewardedAdUnitId,
    rewardedInterstitialAdUnitId,
    appOpenAdUnitId,
    testMode,
    enabledFormats == null ? null : Object.hashAllUnordered(enabledFormats!),
    requiredFormats == null ? null : Object.hashAllUnordered(requiredFormats!),
    Object.hashAll(testDeviceIds),
    Object.hashAllUnordered(extras.keys),
  );
}

void _validateExtrasValue(Object? value, String path) {
  if (value == null) {
    throw ArgumentError('$path: extras value must not be null');
  }
  if (value is String) {
    if (value.length > configExtrasMaxValueLength) {
      throw ArgumentError(
        '$path: extras string value exceeds $configExtrasMaxValueLength characters',
      );
    }
    return;
  }
  if (value is int) return;
  if (value is double) return;
  if (value is bool) return;
  if (value is List<Object?>) {
    if (value.length > configExtrasMaxEntries) {
      throw ArgumentError(
        '$path: extras list has ${value.length} entries (max $configExtrasMaxEntries)',
      );
    }
    for (final (i, item) in value.indexed) {
      if (item is! String &&
          item is! int &&
          item is! double &&
          item is! bool &&
          item != null) {
        throw ArgumentError(
          '$path[$i]: extras list items must be String, int, double, bool, or null',
        );
      }
      if (item is String && item.length > configExtrasMaxValueLength) {
        throw ArgumentError(
          '$path[$i]: extras list string exceeds $configExtrasMaxValueLength characters',
        );
      }
    }
    return;
  }
  if (value is Map<String, Object?>) {
    if (value.length > configExtrasMaxEntries) {
      throw ArgumentError(
        '$path: extras map has ${value.length} entries (max $configExtrasMaxEntries)',
      );
    }
    for (final MapEntry(key: k, value: v) in value.entries) {
      if (k.isEmpty) {
        throw ArgumentError(
          '$path.$k: extras map keys must be non-empty strings',
        );
      }
      _validateExtrasValue(v, '$path.$k');
    }
    return;
  }
  throw ArgumentError(
    '$path: extras value must be String, int, double, bool, List, or Map<String, Object?>',
  );
}
