// Public test credentials used by integration_test/ad_smoke_test.dart (and the
// iOS CI pipeline, .github/workflows/ios.yml). Mirrors the "Public test IDs"
// table in doc/getting_ids.md; keep the two in sync.
//
// Self-contained (imports only unified_ads and foundation) so
// tool/ios_sim_smoke.sh can copy it into scratch apps.
import 'package:flutter/foundation.dart';
import 'package:unified_ads/unified_ads.dart';

/// How strictly the smoke test treats a network.
enum SmokeTier {
  /// Must initialize, load and show; any failure fails the run.
  required,

  /// Must initialize without errors. A no-fill / timeout / network error on
  /// load is reported as SKIP: these networks don't reliably serve test ads
  /// to a CI simulator.
  bestEffort,
}

/// What the smoke test runs for one network on the current platform.
class SmokeTarget {
  /// Creates a target. A null [config] means the network has no public test
  /// credentials on this platform; [skipReason] then says why.
  const SmokeTarget({required this.tier, this.config, this.skipReason});

  /// How strictly failures are treated.
  final SmokeTier tier;

  /// Public test credentials, or null when there are none.
  final NetworkConfig? config;

  /// Why the network is skipped entirely, or null when it runs.
  final String? skipReason;
}

bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

/// The smoke target for every network on the current platform.
Map<AdNetwork, SmokeTarget> smokeTargets() => {
  // https://developers.google.com/admob/ios/test-ads
  // https://developers.google.com/admob/android/test-ads
  AdNetwork.admob: SmokeTarget(
    tier: SmokeTier.required,
    config: NetworkConfig(
      appId: _ios
          ? 'ca-app-pub-3940256099942544~1458002511'
          : 'ca-app-pub-3940256099942544~3347511713',
      interstitialAdUnitId: _ios
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-3940256099942544/1033173712',
    ),
  ),
  AdNetwork.unity: _ios
      // Unity's iOS sample (github.com/Unity-Technologies/unity-ads-ios,
      // Example/UnityAdsExample/ViewController.m).
      ? const SmokeTarget(
          tier: SmokeTier.bestEffort,
          config: NetworkConfig(appId: '14850', interstitialAdUnitId: 'video'),
        )
      // Unity's sample game (github.com/Unity-Technologies/unity-ads-android).
      : const SmokeTarget(
          tier: SmokeTier.bestEffort,
          config: NetworkConfig(
            appId: '14851',
            interstitialAdUnitId: 'rewardedVideo',
          ),
        ),
  AdNetwork.applovin: const SmokeTarget(
    tier: SmokeTier.bestEffort,
    skipReason: 'AppLovin MAX publishes no test SDK key',
  ),
  AdNetwork.ironsource: _ios
      // github.com/ironsource-mobile/Mediation-Demo-Apps
      // (iOS/Swift/LevelPlayDemo/DemoViewController.swift).
      ? const SmokeTarget(
          tier: SmokeTier.bestEffort,
          config: NetworkConfig(
            appId: '25c43a4a5',
            interstitialAdUnitId: 'obg6ohwts3y690ks',
          ),
        )
      // github.com/ironsource-mobile/Mediation-Demo-Apps
      : const SmokeTarget(
          tier: SmokeTier.bestEffort,
          config: NetworkConfig(
            appId: '25b63cf85',
            interstitialAdUnitId: 'h3xw38h9214adgxo',
          ),
        ),
  // Test placements from the facebook_audience_network plugin's example
  // (an Android app; on iOS the IMG_16_9_APP_INSTALL# test form is expected
  // to work but unverified). Audience Network needs no app ID in code.
  AdNetwork.facebook: const SmokeTarget(
    tier: SmokeTier.bestEffort,
    config: NetworkConfig(
      interstitialAdUnitId:
          'IMG_16_9_APP_INSTALL#2312433698835503_2650502525028617',
    ),
  ),
  AdNetwork.startapp: _ios
      ? const SmokeTarget(
          tier: SmokeTier.bestEffort,
          skipReason:
              'Start.io publishes no iOS demo app ID (its iOS samples use '
              'a placeholder)',
        )
      // github.com/StartApp-SDK/android-sdk-demo
      : const SmokeTarget(
          tier: SmokeTier.bestEffort,
          config: NetworkConfig(appId: '205489527'),
        ),
  AdNetwork.inmobi: _ios
      // github.com/InMobi/sdk-sample-code-ios (InterstitialSwiftSample).
      ? const SmokeTarget(
          tier: SmokeTier.bestEffort,
          config: NetworkConfig(
            appId: '4028cb8b2c3a0b45012c406824e800ba',
            interstitialAdUnitId: '1672200162238',
          ),
        )
      // github.com/InMobi/sdk-sample-code-android
      : const SmokeTarget(
          tier: SmokeTier.bestEffort,
          config: NetworkConfig(
            appId: '8ba05e170e914971a0b45d977809a6cf',
            interstitialAdUnitId: '1476878485960',
          ),
        ),
};
