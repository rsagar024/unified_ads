/// Checks an iOS app's Info.plist (and optionally its privacy manifest) for
/// the entries each selected ad network needs. Exits 1 on a missing required
/// entry, 2 on bad usage or an unreadable file.
///
///     dart run tool/verify_ios_plist.dart --plist ios/Runner/Info.plist \
///       --networks admob,unity [--privacy ios/Runner/PrivacyInfo.xcprivacy]
///     dart run tool/verify_ios_plist.dart --list-skadnetwork-ids ///       --networks admob,unity
///
/// Requirements per network: doc/ios_setup.md (rules: tool/src/ios_plist_rules.dart).
library;

import 'dart:io';

import 'package:args/args.dart';

import 'src/ios_plist_rules.dart';
import 'src/plist.dart';
import 'src/verify_ios_plist.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('plist', help: 'Path to the app Info.plist.')
    ..addOption(
      'networks',
      help:
          'Comma-separated network ids '
          '(${iosPlistRules.keys.join(', ')}).',
      mandatory: true,
    )
    ..addOption('privacy', help: 'Path to the app PrivacyInfo.xcprivacy.')
    ..addFlag(
      'list-skadnetwork-ids',
      negatable: false,
      help:
          'Print the SKAdNetwork IDs the networks need, one per line, and '
          'exit (used by tool/ios_sim_smoke.sh).',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln(parser.usage);
      return;
    }
    if (!args.flag('list-skadnetwork-ids') && args.option('plist') == null) {
      throw const FormatException('Option plist is mandatory.');
    }
    args.option('networks');
  } on Object catch (e) {
    stderr
      ..writeln(e)
      ..writeln(parser.usage);
    exitCode = 2;
    return;
  }

  final networks = [
    for (final n in args.option('networks')!.split(','))
      if (n.trim().isNotEmpty) n.trim(),
  ];
  if (args.flag('list-skadnetwork-ids')) {
    for (final n in networks) {
      final rule = iosPlistRules[n];
      if (rule == null) {
        stderr.writeln('unknown network: $n');
        exitCode = 2;
        return;
      }
      rule.skAdNetworkIds.forEach(stdout.writeln);
    }
    return;
  }

  final findings = <PlistFinding>[];
  try {
    findings.addAll(verifyInfoPlist(_read(args.option('plist')!), networks));
    final privacy = args.option('privacy');
    if (privacy != null) {
      findings.addAll(verifyPrivacyManifest(_read(privacy)));
    }
  } on Object catch (e) {
    stderr.writeln(e);
    exitCode = 2;
    return;
  }

  findings.forEach(stdout.writeln);
  final errors = findings.where((f) => f.severity == PlistSeverity.error);
  if (errors.isNotEmpty) {
    stdout.writeln(
      '${errors.length} required entr'
      '${errors.length == 1 ? 'y' : 'ies'} missing '
      '(networks: ${networks.join(', ')}). See doc/ios_setup.md.',
    );
    exitCode = 1;
  } else {
    stdout.writeln(
      'iOS plist check passed (networks: ${networks.join(', ')}).',
    );
  }
}

Map<String, Object?> _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw PlistFormatException('$path does not exist');
  final value = parsePlist(file.readAsStringSync());
  if (value is! Map<String, Object?>) {
    throw PlistFormatException('$path: top-level value is not a <dict>');
  }
  return value;
}
