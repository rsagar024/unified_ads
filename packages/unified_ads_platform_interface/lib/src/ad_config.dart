import 'package:flutter/foundation.dart';

import 'ad_format.dart';
import 'ad_network.dart';
import 'frequency_cap.dart';
import 'network_config.dart';
import 'preload_policy.dart';

/// Top-level unified_ads configuration.
///
/// ```dart
/// AdConfig(
///   testMode: true,
///   waterfall: [AdNetwork.admob, AdNetwork.unity, AdNetwork.inmobi],
///   networks: {
///     AdNetwork.admob: NetworkConfig(
///       appId: 'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy',
///       interstitialAdUnitId: '...',
///     ),
///   },
/// )
/// ```
@immutable
class AdConfig {
  /// Creates a configuration.
  const AdConfig({
    this.testMode = false,
    this.waterfall = const [],
    this.networks = const {},
    this.loadTimeout = const Duration(seconds: 10),
    this.initTimeout = const Duration(seconds: 20),
    this.preload = const PreloadPolicy(),
    this.frequencyCaps = const {},
    this.cacheTtl = const Duration(hours: 1),
  });

  /// Global test-mode flag; `NetworkConfig.testMode` overrides it per network.
  ///
  /// Test mode is best effort: some networks (for example InMobi) can only be
  /// switched to test mode from their dashboard. See `TestModeSupport`.
  final bool testMode;

  /// Network priority order. When empty, every configured network is used in
  /// [AdNetwork] declaration order. Networks missing from a non-empty list
  /// never serve, except through an explicit `forceNetwork`.
  final List<AdNetwork> waterfall;

  /// Per-network credentials and options.
  final Map<AdNetwork, NetworkConfig> networks;

  /// Maximum time for one waterfall attempt.
  final Duration loadTimeout;

  /// Maximum time for one network's SDK initialization.
  final Duration initTimeout;

  /// Automatic preloading of full-screen ads.
  final PreloadPolicy preload;

  /// Optional frequency caps per full-screen format.
  final Map<AdFormat, FrequencyCap> frequencyCaps;

  /// How long a cached (preloaded) ad stays valid.
  final Duration cacheTtl;

  /// The networks to try, in order (see [waterfall]).
  List<AdNetwork> get effectiveWaterfall {
    if (waterfall.isNotEmpty) return List.unmodifiable(waterfall);
    return List.unmodifiable(AdNetwork.values.where(networks.containsKey));
  }

  /// Whether test ads are requested for [network].
  bool isTestMode(AdNetwork network) => networks[network]?.testMode ?? testMode;

  /// Returns a copy with the given fields replaced.
  AdConfig copyWith({
    bool? testMode,
    List<AdNetwork>? waterfall,
    Map<AdNetwork, NetworkConfig>? networks,
    Duration? loadTimeout,
    Duration? initTimeout,
    PreloadPolicy? preload,
    Map<AdFormat, FrequencyCap>? frequencyCaps,
    Duration? cacheTtl,
  }) {
    return AdConfig(
      testMode: testMode ?? this.testMode,
      waterfall: waterfall ?? this.waterfall,
      networks: networks ?? this.networks,
      loadTimeout: loadTimeout ?? this.loadTimeout,
      initTimeout: initTimeout ?? this.initTimeout,
      preload: preload ?? this.preload,
      frequencyCaps: frequencyCaps ?? this.frequencyCaps,
      cacheTtl: cacheTtl ?? this.cacheTtl,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdConfig &&
      other.testMode == testMode &&
      listEquals(other.waterfall, waterfall) &&
      mapEquals(other.networks, networks) &&
      other.loadTimeout == loadTimeout &&
      other.initTimeout == initTimeout &&
      other.preload == preload &&
      mapEquals(other.frequencyCaps, frequencyCaps) &&
      other.cacheTtl == cacheTtl;

  @override
  int get hashCode => Object.hash(
    testMode,
    Object.hashAll(waterfall),
    Object.hashAllUnordered(networks.keys),
    loadTimeout,
    initTimeout,
    preload,
    Object.hashAllUnordered(frequencyCaps.keys),
    cacheTtl,
  );
}
