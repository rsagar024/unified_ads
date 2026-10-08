import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/src/cli/generate_config.dart';
import 'package:unified_ads/src/config_schema.dart';
import 'package:unified_ads/unified_ads.dart';

const _pubspec = '''
name: my_app
dependencies:
  flutter:
    sdk: flutter

unified_ads:
  testMode: true
  waterfall: [admob, unity]
  loadTimeoutMs: 8000
  preload:
    formats: [interstitial]
    onInit: true
  frequencyCaps:
    interstitial: {maxShows: 2, perSeconds: 600}
  networks:
    admob:
      appId:
        android: ca-app-pub-3940256099942544~3347511713
        ios: ca-app-pub-3940256099942544~1458002511
      bannerAdUnitId: banner-unit
      enabledFormats: [banner]
    unity:
      appId: '14851'
      testMode: false
      extras: {rewardAmount: 5}
''';

void main() {
  late Directory dir;
  late File pubspec;
  late File output;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('generate_config_test');
    pubspec = File('${dir.path}/pubspec.yaml')..writeAsStringSync(_pubspec);
    output = File('${dir.path}/assets/ads_config.json');
    out = StringBuffer();
    err = StringBuffer();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  int run([List<String> extra = const []]) => runGenerateConfig(
    ['--pubspec', pubspec.path, '--output', output.path, ...extra],
    out: out,
    err: err,
  );

  test('schema id lists match AdNetwork and AdFormat', () {
    expect(configNetworkIds, [for (final n in AdNetwork.values) n.id]);
    expect(configFormatIds, [for (final f in AdFormat.values) f.id]);
  });

  test('writes JSON that AdConfigLoader accepts', () {
    expect(run(), 0, reason: '$err');
    expect(out.toString(), contains('Wrote'));

    final config = AdConfigLoader.fromJsonString(
      output.readAsStringSync(),
      platform: TargetPlatform.iOS,
    ).valueOrNull!;
    expect(config.testMode, isTrue);
    expect(config.waterfall, [AdNetwork.admob, AdNetwork.unity]);
    expect(config.loadTimeout, const Duration(seconds: 8));
    expect(
      config.preload,
      const PreloadPolicy(formats: {AdFormat.interstitial}, onInit: true),
    );
    expect(config.frequencyCaps[AdFormat.interstitial]?.maxShows, 2);
    final admob = config.networks[AdNetwork.admob]!;
    expect(admob.appId, 'ca-app-pub-3940256099942544~1458002511');
    expect(admob.enabledFormats, {AdFormat.banner});
    expect(config.networks[AdNetwork.unity]!.extras, {'rewardAmount': 5});
  });

  test('the committed CI fixture is loadable', () {
    final result = AdConfigLoader.fromJsonString(
      File('test/fixtures/ads_config.json').readAsStringSync(),
    );
    expect(result.errorOrNull, isNull);
    expect(result.valueOrNull!.waterfall, hasLength(3));
  });

  test('is idempotent and --set-exit-if-changed detects drift', () {
    expect(run(), 0);
    final first = output.readAsStringSync();

    expect(run(['--set-exit-if-changed']), 0);
    expect(out.toString(), contains('up to date'));

    output.writeAsStringSync('{}\n');
    expect(run(['--set-exit-if-changed']), 1);
    expect(err.toString(), contains('out of date'));
    expect(
      output.readAsStringSync(),
      '{}\n',
      reason: 'check mode never writes',
    );

    expect(run(), 0);
    expect(output.readAsStringSync(), first);
  });

  test('reports schema errors with a JSON path', () {
    pubspec.writeAsStringSync(
      'unified_ads:\n  networks:\n    admob:\n'
      '      bogus: 1\n',
    );
    expect(run(), 2);
    expect(err.toString(), contains(r'$.networks.admob.bogus: unknown key'));
    expect(output.existsSync(), isFalse);
  });

  test('rejects unknown networks', () {
    pubspec.writeAsStringSync('unified_ads:\n  waterfall: [admob, meta]\n');
    expect(run(), 2);
    expect(err.toString(), contains(r'$.waterfall[1]: unknown network "meta"'));
  });

  test('fails without a unified_ads section or pubspec', () {
    pubspec.writeAsStringSync('name: my_app\n');
    expect(run(), 2);
    expect(err.toString(), contains('no top-level `unified_ads:`'));

    pubspec.deleteSync();
    expect(run(), 2);
    expect(err.toString(), contains('not found'));
  });

  test('rejects bad options', () {
    expect(runGenerateConfig(['--output'], out: out, err: err), 2);
    expect(err.toString(), contains('Unknown or incomplete option'));
    expect(runGenerateConfig(['--help'], out: out, err: err), 0);
    expect(out.toString(), contains('Usage'));
  });

  test('loader and schema report identical errors', () {
    const bad = [
      '{"testMode": 1}',
      '{"networks": {"admob": {"appId": 5}}}',
      '{"networks": {"admob": {"appId": {"web": "x"}}}}',
      '{"preload": {"formats": ["video"]}}',
      '{"frequencyCaps": {"banner": {"maxShows": 1}}}',
      '{"networks": {"unity": {"enabledFormats": [1]}}}',
      '{"networks": {"inmobi": []}}',
    ];
    for (final source in bad) {
      final json = jsonDecode(source) as Map<String, Object?>;
      expect(
        AdConfigLoader.fromJson(json).errorOrNull?.message,
        validateConfigJson(json),
        reason: source,
      );
      expect(validateConfigJson(json), isNotNull, reason: source);
    }
  });
}
