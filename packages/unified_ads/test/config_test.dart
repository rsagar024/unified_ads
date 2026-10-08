import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/src/config_validator.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

void main() {
  group('validateConfig', () {
    test('accepts a well-formed config', () {
      final report = validateConfig(
        configFor([AdNetwork.admob, AdNetwork.unity]),
      );
      expect(report.isUsable, isTrue);
      expect(report.networks, isEmpty);
    });

    test('rejects waterfall entries that are duplicated or unconfigured', () {
      final report = validateConfig(
        AdConfig(
          waterfall: const [AdNetwork.admob, AdNetwork.admob, AdNetwork.unity],
          networks: {AdNetwork.admob: netConfig()},
        ),
      );
      expect(report.isUsable, isFalse);
      expect(report.global.map((e) => e.message), [
        contains('listed twice'),
        contains('unity has no entry'),
      ]);
    });

    test('rejects non-positive timeouts and caps', () {
      final report = validateConfig(
        const AdConfig(
          loadTimeout: Duration.zero,
          frequencyCaps: {
            AdFormat.banner: FrequencyCap(maxShows: 0, per: Duration(hours: 1)),
          },
        ),
      );
      expect(report.global, hasLength(3));
    });

    test('per-network rules disable only that network', () {
      final report = validateConfig(
        AdConfig(
          networks: {
            AdNetwork.admob: netConfig(appId: ' '),
            AdNetwork.inmobi: netConfig(interstitial: 'not-a-number'),
            AdNetwork.facebook: const NetworkConfig(),
            AdNetwork.unity: netConfig(appId: null, enabled: false),
          },
        ),
      );
      expect(report.isUsable, isTrue);
      expect(report.networks.keys, {AdNetwork.admob, AdNetwork.inmobi});
      expect(
        report.networks[AdNetwork.inmobi]!.message,
        contains('interstitialAdUnitId must be a numeric'),
      );
    });
  });

  group('AdConfigLoader', () {
    const json = '''
{
  "testMode": true,
  "waterfall": ["admob", "inmobi"],
  "loadTimeoutMs": 5000,
  "cacheTtlSeconds": 1800,
  "preload": {"formats": ["rewarded"], "onInit": true},
  "frequencyCaps": {"interstitial": {"maxShows": 3, "perSeconds": 3600}},
  "networks": {
    "admob": {
      "appId": {"android": "android-app", "ios": "ios-app"},
      "bannerAdUnitId": "banner",
      "interstitialAdUnitId": {"android": "a-int", "ios": "i-int"},
      "enabledFormats": ["banner", "interstitial"],
      "testDeviceIds": ["device"],
      "extras": {"key": 1}
    },
    "inmobi": {"appId": "account", "rewardedAdUnitId": "123", "testMode": false}
  }
}
''';

    test('parses the documented schema', () {
      final config = AdConfigLoader.fromJsonString(
        json,
        platform: TargetPlatform.android,
      ).valueOrNull!;

      expect(config.testMode, isTrue);
      expect(config.waterfall, [AdNetwork.admob, AdNetwork.inmobi]);
      expect(config.loadTimeout, const Duration(seconds: 5));
      expect(config.cacheTtl, const Duration(minutes: 30));
      expect(
        config.preload,
        const PreloadPolicy(formats: {AdFormat.rewarded}, onInit: true),
      );
      expect(config.frequencyCaps[AdFormat.interstitial]?.maxShows, 3);
      final admob = config.networks[AdNetwork.admob]!;
      expect(admob.appId, 'android-app');
      expect(admob.interstitialAdUnitId, 'a-int');
      expect(admob.enabledFormats, {AdFormat.banner, AdFormat.interstitial});
      expect(admob.extras, {'key': 1});
      expect(config.isTestMode(AdNetwork.inmobi), isFalse);
    });

    test('selects iOS values on iOS', () {
      final config = AdConfigLoader.fromJsonString(
        json,
        platform: TargetPlatform.iOS,
      ).valueOrNull!;
      expect(config.networks[AdNetwork.admob]!.appId, 'ios-app');
    });

    test('round-trips through toJson', () {
      final config = AdConfigLoader.fromJsonString(
        json,
        platform: TargetPlatform.android,
      ).valueOrNull!;
      final again = AdConfigLoader.fromJson(
        jsonDecode(jsonEncode(AdConfigLoader.toJson(config)))
            as Map<String, Object?>,
      ).valueOrNull;
      expect(again, config);
    });

    test('reports errors with a JSON path', () {
      String? error(String source) =>
          AdConfigLoader.fromJsonString(source).errorOrNull?.message;

      expect(
        error('{"networks": {"admob": {"bogus": 1}}}'),
        r'$.networks.admob.bogus: unknown key',
      );
      expect(
        error('{"networks": {"meta": {}}}'),
        contains(r'$.networks.meta: unknown network'),
      );
      expect(error('{"testMode": "yes"}'), r'$.testMode: expected bool');
      expect(
        error('{"waterfall": ["admob", 3]}'),
        r'$.waterfall[1]: expected a string',
      );
      expect(
        error('{"networks": {"admob": {"appId": 5}}}'),
        contains(r'$.networks.admob.appId'),
      );
      expect(
        error('{"frequencyCaps": {"rewarded": {"maxShows": 1}}}'),
        contains('perSeconds are required'),
      );
      expect(error('[1]'), contains('root must be a JSON object'));
      expect(error('{oops'), startsWith('Invalid JSON'));
    });

    test('loads from an asset bundle', () async {
      final bundle = _StringBundle({'ads.json': '{"testMode": true}'});

      final ok = await AdConfigLoader.fromAsset('ads.json', bundle: bundle);
      final missing = await AdConfigLoader.fromAsset(
        'nope.json',
        bundle: bundle,
      );

      expect(ok.valueOrNull?.testMode, isTrue);
      expect(missing.errorOrNull?.code, AdErrorCode.invalidConfig);
    });
  });
}

class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final content = files[key];
    if (content == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}
