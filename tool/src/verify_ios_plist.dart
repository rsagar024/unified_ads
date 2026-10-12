/// Checks for tool/verify_ios_plist.dart, separated from the CLI so they can
/// be unit-tested (tool/test/verify_ios_plist_test.dart).
library;

import 'ios_plist_rules.dart';

/// How serious a [PlistFinding] is.
enum PlistSeverity {
  /// A required entry is missing; the verifier exits non-zero.
  error,

  /// Recommended but not required; printed only.
  warning,
}

/// One problem found in an Info.plist or privacy manifest.
class PlistFinding {
  /// Creates a finding.
  const PlistFinding(this.severity, this.file, this.message);

  /// How serious it is.
  final PlistSeverity severity;

  /// `Info.plist` or `PrivacyInfo.xcprivacy`.
  final String file;

  /// What is missing and why it is needed.
  final String message;

  @override
  String toString() =>
      '${severity == PlistSeverity.error ? 'ERROR' : 'WARN '} [$file] $message';
}

/// Checks a parsed Info.plist for what [networks] need.
///
/// Throws [ArgumentError] for an unknown network id.
List<PlistFinding> verifyInfoPlist(
  Map<String, Object?> info,
  Iterable<String> networks,
) {
  const file = 'Info.plist';
  final findings = <PlistFinding>[];
  final rules = [
    for (final n in networks)
      iosPlistRules[n] ??
          (throw ArgumentError.value(
            n,
            'networks',
            'unknown network (known: ${iosPlistRules.keys.join(', ')})',
          )),
  ];
  if (rules.isEmpty) return findings;

  commonRequiredKeys.forEach((key, why) {
    if (!_present(info[key])) {
      findings.add(
        PlistFinding(PlistSeverity.error, file, '$key missing: $why'),
      );
    }
  });

  final declared = _skAdNetworkIds(info['SKAdNetworkItems']);
  for (final rule in rules) {
    rule.requiredKeys.forEach((key, why) {
      if (!_present(info[key])) {
        findings.add(
          PlistFinding(
            PlistSeverity.error,
            file,
            '$key missing (${rule.network}): $why',
          ),
        );
      }
    });
    for (final id in rule.skAdNetworkIds) {
      if (!declared.contains(id)) {
        findings.add(
          PlistFinding(
            PlistSeverity.error,
            file,
            'SKAdNetworkItems lacks $id (${rule.network}; see ${rule.source})',
          ),
        );
      }
    }
  }
  return findings;
}

/// Checks a parsed privacy manifest (PrivacyInfo.xcprivacy).
List<PlistFinding> verifyPrivacyManifest(Map<String, Object?> manifest) {
  const file = 'PrivacyInfo.xcprivacy';
  final findings = <PlistFinding>[];
  privacyManifestKeys.forEach((key, why) {
    if (!manifest.containsKey(key)) {
      findings.add(
        PlistFinding(PlistSeverity.error, file, '$key missing: $why'),
      );
    }
  });
  if (manifest['NSPrivacyTracking'] != true) {
    findings.add(
      const PlistFinding(
        PlistSeverity.warning,
        file,
        'NSPrivacyTracking is not true; ad SDKs that use the IDFA track users',
      ),
    );
  }
  final collected = manifest['NSPrivacyCollectedDataTypes'];
  final advertising =
      collected is List &&
      collected.any(
        (t) =>
            t is Map &&
            (t['NSPrivacyCollectedDataTypePurposes'] as List? ?? const [])
                .contains(
                  'NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising',
                ),
      );
  if (!advertising) {
    findings.add(
      const PlistFinding(
        PlistSeverity.warning,
        file,
        'no NSPrivacyCollectedDataTypes entry has the purpose '
        'NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising',
      ),
    );
  }
  return findings;
}

bool _present(Object? value) => switch (value) {
  null => false,
  final String s => s.trim().isNotEmpty,
  final List<Object?> l => l.isNotEmpty,
  _ => true,
};

Set<String> _skAdNetworkIds(Object? items) => {
  if (items is List)
    for (final item in items)
      if (item is Map && item['SKAdNetworkIdentifier'] is String)
        (item['SKAdNetworkIdentifier']! as String).trim().toLowerCase(),
};
