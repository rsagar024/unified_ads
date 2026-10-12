import 'dart:io';

import 'package:test/test.dart';

import '../src/plist.dart';
import '../src/verify_ios_plist.dart';

Map<String, Object?> _fixture(String name) =>
    parsePlist(File('tool/test/fixtures/$name').readAsStringSync())!
        as Map<String, Object?>;

List<String> _errors(List<PlistFinding> findings) => [
  for (final f in findings)
    if (f.severity == PlistSeverity.error) f.message,
];

void main() {
  group('parsePlist', () {
    test('reads dict, array, string, bool and integer values', () {
      final info = _fixture('complete_info.plist');
      expect(info['CFBundleName'], 'fixture');
      expect(info['UIRequiresFullScreen'], isTrue);
      expect(info['LSApplicationCategoryVersion'], 3);
      expect(info['SKAdNetworkItems'], hasLength(2));
    });

    test('rejects non-plist XML', () {
      expect(
        () => parsePlist('<html></html>'),
        throwsA(isA<PlistFormatException>()),
      );
    });
  });

  group('verifyInfoPlist', () {
    test('passes when every required entry is present', () {
      final findings = verifyInfoPlist(_fixture('complete_info.plist'), [
        'admob',
        'unity',
      ]);
      expect(_errors(findings), isEmpty);
    });

    test('SKAdNetwork IDs are compared case-insensitively', () {
      // The fixture lists Unity's ID in upper case.
      expect(
        _errors(verifyInfoPlist(_fixture('complete_info.plist'), ['unity'])),
        isEmpty,
      );
    });

    test('reports a missing network-specific key', () {
      final info = _fixture('complete_info.plist')
        ..remove('GADApplicationIdentifier');
      expect(_errors(verifyInfoPlist(info, ['admob'])), [
        contains('GADApplicationIdentifier missing'),
      ]);
    });

    test('reports missing common keys and SKAdNetwork IDs', () {
      final info = _fixture('complete_info.plist')
        ..remove('NSUserTrackingUsageDescription');
      final errors = _errors(verifyInfoPlist(info, ['inmobi']));
      expect(errors, hasLength(2));
      expect(errors[0], contains('NSUserTrackingUsageDescription'));
      expect(errors[1], contains('wzmmz9fp6w.skadnetwork'));
    });

    test('an empty string value counts as missing', () {
      final info = _fixture('complete_info.plist')
        ..['NSUserTrackingUsageDescription'] = ' ';
      expect(_errors(verifyInfoPlist(info, ['admob'])), hasLength(1));
    });

    test('no networks means nothing to check', () {
      expect(verifyInfoPlist(const {}, const []), isEmpty);
    });

    test('rejects an unknown network', () {
      expect(() => verifyInfoPlist(const {}, ['meta']), throwsArgumentError);
    });
  });

  group('verifyPrivacyManifest', () {
    test('passes a complete manifest without warnings', () {
      expect(
        verifyPrivacyManifest(_fixture('privacy_complete.xcprivacy')),
        isEmpty,
      );
    });

    test('missing keys are errors, no tracking is a warning', () {
      final findings = verifyPrivacyManifest(const {
        'NSPrivacyTracking': false,
      });
      expect(_errors(findings), hasLength(3));
      expect(
        findings.where((f) => f.severity == PlistSeverity.warning),
        hasLength(2),
      );
    });
  });

  group('CLI', () {
    Future<ProcessResult> run(List<String> args) => Process.run(
      Platform.resolvedExecutable,
      ['run', 'tool/verify_ios_plist.dart', ...args],
    );

    test('exits 0 when complete', () async {
      final result = await run([
        '--plist',
        'tool/test/fixtures/complete_info.plist',
        '--networks',
        'admob,unity',
        '--privacy',
        'tool/test/fixtures/privacy_complete.xcprivacy',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('exits 1 when a required entry is missing', () async {
      final result = await run([
        '--plist',
        'tool/test/fixtures/complete_info.plist',
        '--networks',
        'facebook',
      ]);
      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect('${result.stdout}', contains('v9wttpbfk9.skadnetwork'));
    });

    test('--list-skadnetwork-ids prints the IDs', () async {
      final result = await run([
        '--list-skadnetwork-ids',
        '--networks',
        'admob,facebook',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}'.trim().split(RegExp(r'\s+')), [
        'cstr6suwn9.skadnetwork',
        'v9wttpbfk9.skadnetwork',
        'n38lu8286q.skadnetwork',
      ]);
    });

    test('exits 2 without --plist', () async {
      final result = await run(['--networks', 'admob']);
      expect(result.exitCode, 2);
    });

    test('exits 2 on a missing file', () async {
      final result = await run([
        '--plist',
        'does/not/exist.plist',
        '--networks',
        'admob',
      ]);
      expect(result.exitCode, 2);
    });
  });
}
