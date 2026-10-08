/// Converts the `unified_ads:` section of an app's pubspec.yaml into
/// `assets/ads_config.json`.
///
/// Run `dart run unified_ads:generate_config --help` for options.
library;

import 'dart:io';

import 'package:unified_ads/src/cli/generate_config.dart';

void main(List<String> args) {
  exitCode = runGenerateConfig(args, out: stdout, err: stderr);
}
