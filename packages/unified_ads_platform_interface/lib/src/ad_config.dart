import 'package:flutter/foundation.dart';

import 'ad_format.dart';
import 'ad_network.dart';
import 'ad_pacing.dart';
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
    this.showTimeout = const Duration(seconds: 15),
    this.preload = const PreloadPolicy(),
    this.frequencyCaps = const {},
    this.pacing = const {},
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

  /// Maximum time for a full-screen ad to start presenting after `show()`.
  ///
  /// When the network's SDK reports neither "shown" nor "failed to show"
  /// within this time, `show()` fails with `AdErrorCode.timeout` instead of
  /// waiting forever.
  final Duration showTimeout;

  /// Automatic preloading of full-screen ads.
  final PreloadPolicy preload;

  /// Optional frequency caps per full-screen format.
  final Map<AdFormat, FrequencyCap> frequencyCaps;

  /// Optional timing rules per full-screen format: cooldown between shows,
  /// "show every N actions" and an initial delay after launch.
  final Map<AdFormat, AdPacing> pacing;

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
    Duration? showTimeout,
    PreloadPolicy? preload,
    Map<AdFormat, FrequencyCap>? frequencyCaps,
    Map<AdFormat, AdPacing>? pacing,
    Duration? cacheTtl,
  }) {
    return AdConfig(
      testMode: testMode ?? this.testMode,
      waterfall: waterfall ?? this.waterfall,
      networks: networks ?? this.networks,
      loadTimeout: loadTimeout ?? this.loadTimeout,
      initTimeout: initTimeout ?? this.initTimeout,
      showTimeout: showTimeout ?? this.showTimeout,
      preload: preload ?? this.preload,
      frequencyCaps: frequencyCaps ?? this.frequencyCaps,
      pacing: pacing ?? this.pacing,
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
      other.showTimeout == showTimeout &&
      other.preload == preload &&
      mapEquals(other.frequencyCaps, frequencyCaps) &&
      mapEquals(other.pacing, pacing) &&
      other.cacheTtl == cacheTtl;

  @override
  int get hashCode => Object.hash(
    testMode,
    Object.hashAll(waterfall),
    Object.hashAllUnordered(networks.keys),
    loadTimeout,
    initTimeout,
    showTimeout,
    preload,
    Object.hashAllUnordered(frequencyCaps.keys),
    Object.hashAllUnordered(pacing.keys),
    cacheTtl,
  );
}
