/// CI check: fails the build if any known demo/ad-test ID string appears in
/// production (non-test, non-example) source.
///
/// This guards against the CROSS-01 class of issue: hardcoded vendor demo
/// credentials being copied into production source outside `example/`.
///
/// Exempt:
/// - `example/` — the example app may hold CI-only test credentials
///   (`integration_test/smoke_ids.dart`, `plugin_integration_test.dart`) and
///   its `test_credentials.dart` now holds only `YOUR_*` placeholders.
/// - `test/` directories — unit/integration test fixtures using demo IDs for
///   verification do not ship to production.
/// - This script itself (it stores the detection patterns).
///
/// Run: `dart run tool/verify_no_demo_ids.dart`
library;

import 'dart:io';

const _libDir = 'lib';

/// Known demo/test ID substrings that must never appear in production source
/// outside `example/`. These are the values formerly hardcoded in
/// `example/lib/src/test_credentials.dart` (CROSS-01).
final _demoIds = <String>[
  // AdMob Google demo App ID and ad units
  'ca-app-pub-3940256099942544',
  // Unity Ads sample game ID
  '14851',
  // Start.io demo App ID
  '205489527',
  // InMobi demo account ID
  '8ba05e170e914971a0b45d977809a6cf',
  // LevelPlay demo app key
  '25b63cf85',
  // Facebook demo placement IDs (full values — the prefix alone appears in
  // doc comments explaining the format, which is not a credential).
  'IMG_16_9_APP_INSTALL#2312433698835503_2964944860251047',
  'IMG_16_9_APP_INSTALL#2312433698835503_2650502525028617',
];

/// Path of this script so it doesn't flag itself.
late final String _scriptPath;

bool _isExempt(String path) {
  final p = path.replaceAll('\\', '/');
  // Exclude this script.
  if (p == _scriptPath) return true;
  // Exclude example/ entirely.
  if (p.contains('/example/') || p.startsWith('example/')) return true;
  // Exclude test/ directories (test fixtures don't ship to production).
  final parts = p.split('/');
  if (parts.contains('test')) return true;
  // Only scan production lib/ source.
  if (!parts.contains(_libDir)) return true;
  return false;
}

void main() {
  _scriptPath = Platform.script.toFilePath();
  final failures = <String>[];

  void scanDir(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        scanDir(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        final rel = entity.path.replaceAll('\\', '/');
        if (_isExempt(rel)) continue;
        _scanFile(entity, failures);
      }
    }
  }

  // Scan every package's lib/ directory.
  final packages = Directory('packages');
  if (packages.existsSync()) {
    for (final pkg in packages.listSync(followLinks: false)) {
      if (pkg is Directory) {
        final lib = Directory('${pkg.path}/$_libDir');
        if (lib.existsSync()) scanDir(lib);
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln(
        'ERROR: Known demo/test ad IDs found in production source outside example/:');
    for (final f in failures) {
      stderr.writeln('  $f');
    }
    stderr.writeln(
        '\nReplace them with YOUR_* placeholders (see example/lib/src/test_credentials.dart).');
    exitCode = 1;
  } else {
    stdout.writeln(
        'OK: No demo/test ad IDs found in production source outside example/.');
  }
}

void _scanFile(File file, List<String> failures) {
  try {
    final contents = file.readAsStringSync();
    for (final demoId in _demoIds) {
      if (contents.contains(demoId)) {
        failures.add('${file.path}: contains demo ID "$demoId"');
      }
    }
  } catch (_) {
    // Ignore unreadable files.
  }
}
