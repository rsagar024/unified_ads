import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_example/src/settings_store.dart';
import 'package:unified_ads_example/src/test_credentials.dart';

void main() {
  const store = SettingsStore();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, Object?> json(AdConfig c) => AdConfigLoader.toJson(c);

  test('defaults to the public test credentials', () async {
    final config = await store.load();

    expect(json(config), json(TestCredentials.defaults()));
    expect(config.testMode, isTrue);
    expect(config.networks[AdNetwork.admob]!.enabled, isTrue);
    expect(config.networks[AdNetwork.applovin]!.enabled, isFalse);
    // Unity Ads and LevelPlay cannot run together (A11).
    expect(config.networks[AdNetwork.ironsource]!.enabled, isFalse);
  });

  test('saves and reloads a configuration', () async {
    final edited = TestCredentials.defaults().copyWith(
      testMode: false,
      waterfall: const [AdNetwork.unity, AdNetwork.admob],
      networks: {
        AdNetwork.unity: const NetworkConfig(
          appId: '1234567',
          bannerAdUnitId: 'Banner_Android',
          testMode: true,
        ),
        AdNetwork.admob: TestCredentials.admob,
      },
    );

    await store.save(edited);

    expect(json(await store.load()), json(edited));
  });

  test('reset forgets the saved configuration', () async {
    await store.save(const AdConfig(testMode: false));

    final reset = await store.reset();

    expect(json(reset), json(TestCredentials.defaults()));
    expect(json(await store.load()), json(TestCredentials.defaults()));
  });

  test('ignores a corrupt saved value', () async {
    SharedPreferences.setMockInitialValues({
      'unified_ads_example.config': '{"networks": {"nope": {}}}',
    });

    expect(json(await store.load()), json(TestCredentials.defaults()));
  });
}
