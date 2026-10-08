import 'package:flutter/foundation.dart';

import 'ad_format.dart';

/// Credentials and options for one ad network.
///
/// What [appId] means depends on the network: AdMob App ID, Unity Game ID,
/// AppLovin MAX SDK key, LevelPlay App Key, Start.io App ID or InMobi Account
/// ID. See each adapter's setup doc. Use `PlatformValue.select` for values that
/// differ per platform.
@immutable
class NetworkConfig {
  /// Creates a network configuration.
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

  /// Test device identifiers (AdMob test device IDs, AppLovin GAIDs, …).
  final List<String> testDeviceIds;

  /// Network-specific options, documented per adapter.
  final Map<String, Object?> extras;

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
    List<String>? testDeviceIds,
    Map<String, Object?>? extras,
  }) {
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
      testDeviceIds: testDeviceIds ?? this.testDeviceIds,
      extras: extras ?? this.extras,
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
    Object.hashAll(testDeviceIds),
    Object.hashAllUnordered(extras.keys),
  );
}
