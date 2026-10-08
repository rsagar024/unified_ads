// Pure Dart (no Flutter imports): runs on the plain Dart VM via
// `dart run unified_ads:generate_config`.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../config_schema.dart';

/// Usage text for `dart run unified_ads:generate_config`.
const generateConfigUsage = '''
Converts the `unified_ads:` section of pubspec.yaml into ads_config.json.

Usage: dart run unified_ads:generate_config [options]

  --pubspec <path>         Source pubspec (default: pubspec.yaml)
  --output <path>          Target JSON file (default: assets/ads_config.json)
  --set-exit-if-changed    Exit with code 1 if the output would change
                           (for CI); the file is not written
  -h, --help               Show this help

Exit codes: 0 up to date or written, 1 changed (with --set-exit-if-changed),
2 usage or configuration error.''';

/// Runs the generator with command-line [args] and returns the exit code.
///
/// Messages go to [out] and errors to [err], so tests can capture them.
int runGenerateConfig(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) {
  var pubspecPath = 'pubspec.yaml';
  var outputPath = 'assets/ads_config.json';
  var check = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '-h' || '--help':
        out.writeln(generateConfigUsage);
        return 0;
      case '--set-exit-if-changed':
        check = true;
      case '--pubspec' || '--output' when i + 1 < args.length:
        if (args[i] == '--pubspec') {
          pubspecPath = args[++i];
        } else {
          outputPath = args[++i];
        }
      default:
        err
          ..writeln('Unknown or incomplete option: ${args[i]}')
          ..writeln()
          ..writeln(generateConfigUsage);
        return 2;
    }
  }

  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    err.writeln('$pubspecPath not found.');
    return 2;
  }

  final Object? section;
  try {
    final doc = loadYaml(
      pubspecFile.readAsStringSync(),
      sourceUrl: pubspecFile.uri,
    );
    if (doc is! YamlMap || !doc.containsKey('unified_ads')) {
      err.writeln('$pubspecPath has no top-level `unified_ads:` section.');
      return 2;
    }
    section = _toJson(doc['unified_ads'], r'$');
  } on YamlException catch (e) {
    err.writeln('Invalid YAML: $e');
    return 2;
  } on FormatException catch (e) {
    err.writeln('$pubspecPath unified_ads: ${e.message}');
    return 2;
  }

  if (section is! Map<String, Object?>) {
    err.writeln('$pubspecPath unified_ads: the section must be a map.');
    return 2;
  }
  final error = validateConfigJson(section);
  if (error != null) {
    err.writeln('$pubspecPath unified_ads: $error');
    return 2;
  }

  final json = '${const JsonEncoder.withIndent('  ').convert(section)}\n';
  final outputFile = File(outputPath);
  final current = outputFile.existsSync()
      ? outputFile.readAsStringSync().replaceAll('\r\n', '\n')
      : null;

  if (current == json) {
    out.writeln('$outputPath is up to date.');
    return 0;
  }
  if (check) {
    err.writeln(
      '$outputPath is out of date with $pubspecPath. '
      'Run `dart run unified_ads:generate_config`.',
    );
    return 1;
  }
  outputFile
    ..createSync(recursive: true)
    ..writeAsStringSync(json);
  out
    ..writeln('Wrote $outputPath.')
    ..writeln(
      'Declare it under `flutter: assets:` and load it with '
      'AdConfigLoader.fromAsset.',
    );
  return 0;
}

/// Converts YAML nodes to plain JSON values, rejecting non-string keys and
/// values JSON can't hold.
Object? _toJson(Object? node, String path) => switch (node) {
  YamlMap() => <String, Object?>{
    for (final MapEntry(:key, :value) in node.entries)
      _key(key, path): _toJson(value, '$path.$key'),
  },
  YamlList() => [
    for (final (i, value) in node.indexed) _toJson(value, '$path[$i]'),
  ],
  null || String() || bool() || int() => node,
  double() when node.isFinite => node,
  _ => throw FormatException('$path: unsupported value $node'),
};

String _key(Object? key, String path) => key is String
    ? key
    : throw FormatException('$path: keys must be strings, found $key');
