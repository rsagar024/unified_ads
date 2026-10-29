/// Per-network iOS app requirements checked by tool/verify_ios_plist.dart.
///
/// Documented for humans in doc/ios_setup.md; keep the two in sync. Each
/// SKAdNetwork ID here is the network's OWN identifier. Networks also publish
/// longer partner lists (linked in doc/ios_setup.md), which the verifier does
/// not require.
library;

/// What one network needs in the host app's Info.plist.
class IosPlistRule {
  /// Creates a rule.
  const IosPlistRule({
    required this.network,
    required this.skAdNetworkIds,
    required this.source,
    this.requiredKeys = const {},
  });

  /// Network id, as in `AdNetwork.id` (for example `admob`).
  final String network;

  /// Top-level Info.plist keys the SDK needs, mapped to why.
  final Map<String, String> requiredKeys;

  /// The network's own SKAdNetwork identifiers (lowercase, with the
  /// `.skadnetwork` suffix). Each must appear in `SKAdNetworkItems`.
  final List<String> skAdNetworkIds;

  /// Where [skAdNetworkIds] and [requiredKeys] were taken from.
  final String source;
}

/// Info.plist keys every app using any ad network needs.
///
/// `SKAdNetworkItems` is checked through each rule's
/// [IosPlistRule.skAdNetworkIds].
const commonRequiredKeys = <String, String>{
  'NSUserTrackingUsageDescription':
      'shown by the ATT prompt (UnifiedAds.requestTrackingAuthorization); '
      'requesting tracking without it crashes the app',
};

/// Keys a privacy manifest (PrivacyInfo.xcprivacy) must declare.
const privacyManifestKeys = <String, String>{
  'NSPrivacyTracking':
      'whether the app tracks users (ad SDKs with IDFA: '
      'usually true)',
  'NSPrivacyTrackingDomains': 'domains contacted for tracking (may be empty)',
  'NSPrivacyCollectedDataTypes':
      'data the app collects; ad SDKs collect device ID, advertising data, '
      'product interaction and coarse location for third-party ads',
  'NSPrivacyAccessedAPITypes': 'required-reason APIs the app itself uses',
};

/// The rules, keyed by network id.
const iosPlistRules = <String, IosPlistRule>{
  'admob': IosPlistRule(
    network: 'admob',
    requiredKeys: {
      'GADApplicationIdentifier':
          'Google Mobile Ads SDK terminates the app at launch without it',
    },
    skAdNetworkIds: ['cstr6suwn9.skadnetwork'],
    source: 'https://developers.google.com/admob/ios/quick-start',
  ),
  'unity': IosPlistRule(
    network: 'unity',
    skAdNetworkIds: ['4dzt52r2t5.skadnetwork'],
    source:
        'https://docs.unity.com/en-us/ads-ios/4.18.0/privacy/ios14/'
        'configure-ad-network-ids',
  ),
  'applovin': IosPlistRule(
    network: 'applovin',
    skAdNetworkIds: ['ludvb6z3bs.skadnetwork'],
    source: 'https://support.applovin.com/en/max/ios/overview/skadnetwork',
  ),
  'ironsource': IosPlistRule(
    network: 'ironsource',
    skAdNetworkIds: ['su67r6k2v3.skadnetwork'],
    source:
        'https://docs.unity.com/grow/levelplay/sdk/ios/'
        'skadnetwork-id-manager',
  ),
  'facebook': IosPlistRule(
    network: 'facebook',
    skAdNetworkIds: ['v9wttpbfk9.skadnetwork', 'n38lu8286q.skadnetwork'],
    source:
        'https://developers.facebook.com/documentation/audience-network/'
        'setting-up/platform-setup/ios/SKAdNetwork',
  ),
  // The entry with entity_name "Start.io" in Start.io's published list.
  'startapp': IosPlistRule(
    network: 'startapp',
    skAdNetworkIds: ['5l3tpt7t6e.skadnetwork'],
    source: 'https://www.start.io/skadnetworkids.json',
  ),
  'inmobi': IosPlistRule(
    network: 'inmobi',
    skAdNetworkIds: ['wzmmz9fp6w.skadnetwork'],
    source: 'https://www.inmobi.com/skadnetworkids.json',
  ),
};
