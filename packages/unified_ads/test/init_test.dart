import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/testing.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

void main() {
  tearDown(resetAll);

  test(
    'initializes every configured adapter and reports ready networks',
    () async {
      final admob = FakeAdNetworkAdapter(AdNetwork.admob);
      final unity = FakeAdNetworkAdapter(AdNetwork.unity);
      final config = configFor([AdNetwork.admob, AdNetwork.unity]).copyWith(
        networks: {
          AdNetwork.admob: netConfig(),
          AdNetwork.unity: netConfig(testMode: false),
        },
      );

      final result = await UnifiedAds.init(
        config,
        adapters: [admob, unity],
        consent: const ConsentState(gdprApplies: true, consentGiven: true),
      );

      expect(result.isSuccess, isTrue);
      expect(result.ready, {AdNetwork.admob, AdNetwork.unity});
      expect(UnifiedAds.isInitialized, isTrue);
      expect(UnifiedAds.readyNetworks, {AdNetwork.admob, AdNetwork.unity});
      expect(admob.initializeCalls, 1);
      expect(admob.lastTestMode, isTrue);
      expect(unity.lastTestMode, isFalse, reason: 'per-network override');
      expect(admob.consents.single.consentGiven, isTrue);
      expect(UnifiedAds.lastInitResult, same(result));
    },
  );

  test('uses adapters from the registry', () async {
    final admob = FakeAdNetworkAdapter(AdNetwork.admob);
    AdapterRegistry.instance.register(admob);

    final result = await UnifiedAds.init(configFor([AdNetwork.admob]));

    expect(result.ready, {AdNetwork.admob});
    expect(admob.initializeCalls, 1);
  });

  test(
    'skips networks without an adapter, disabled or misconfigured',
    () async {
      final admob = FakeAdNetworkAdapter(AdNetwork.admob);
      final inmobi = FakeAdNetworkAdapter(AdNetwork.inmobi);
      final startapp = FakeAdNetworkAdapter(AdNetwork.startapp);
      final config = AdConfig(
        networks: {
          AdNetwork.admob: netConfig(),
          AdNetwork.unity: netConfig(),
          AdNetwork.inmobi: netConfig(enabled: false),
          AdNetwork.startapp: netConfig(appId: null),
        },
      );

      final result = await UnifiedAds.init(
        config,
        adapters: [admob, inmobi, startapp],
      );

      expect(result.ready, {AdNetwork.admob});
      expect(result.skipped[AdNetwork.unity]?.code, AdErrorCode.adapterMissing);
      expect(
        result.skipped[AdNetwork.inmobi]?.code,
        AdErrorCode.networkDisabled,
      );
      expect(
        result.skipped[AdNetwork.startapp]?.code,
        AdErrorCode.invalidConfig,
      );
      expect(inmobi.initializeCalls, 0);
      expect(startapp.initializeCalls, 0);
    },
  );

  test('Unity Ads is skipped when LevelPlay is also enabled', () async {
    final unity = FakeAdNetworkAdapter(AdNetwork.unity);
    final levelPlay = FakeAdNetworkAdapter(AdNetwork.ironsource);

    final result = await UnifiedAds.init(
      configFor([AdNetwork.unity, AdNetwork.ironsource]),
      adapters: [unity, levelPlay],
    );

    expect(result.ready, {AdNetwork.ironsource});
    expect(result.skipped[AdNetwork.unity]?.code, AdErrorCode.configConflict);
    expect(unity.initializeCalls, 0);
  });

  test('AppLovin MAX is skipped for child-directed users', () async {
    final max = FakeAdNetworkAdapter(AdNetwork.applovin);
    final admob = FakeAdNetworkAdapter(AdNetwork.admob);

    final result = await UnifiedAds.init(
      configFor([AdNetwork.applovin, AdNetwork.admob]),
      adapters: [max, admob],
      consent: const ConsentState(coppa: true),
    );

    expect(result.ready, {AdNetwork.admob});
    expect(
      result.skipped[AdNetwork.applovin]?.code,
      AdErrorCode.configConflict,
    );
  });

  test('records initialization failures and timeouts', () async {
    final admob = FakeAdNetworkAdapter(AdNetwork.admob)
      ..initError = const AdError(
        code: AdErrorCode.initializationFailed,
        message: 'boom',
      );
    final unity = FakeAdNetworkAdapter(AdNetwork.unity)
      ..initDelay = const Duration(seconds: 2);
    final config = configFor([
      AdNetwork.admob,
      AdNetwork.unity,
    ]).copyWith(initTimeout: const Duration(milliseconds: 50));

    final result = await UnifiedAds.init(config, adapters: [admob, unity]);

    expect(result.ready, isEmpty);
    expect(result.isSuccess, isFalse);
    expect(result.failed[AdNetwork.admob]?.network, AdNetwork.admob);
    expect(
      result.failed[AdNetwork.unity]?.code,
      AdErrorCode.initializationFailed,
    );
    expect(UnifiedAds.isInitialized, isFalse);
  });

  test(
    'an invalid global config fails without initializing anything',
    () async {
      final admob = FakeAdNetworkAdapter(AdNetwork.admob);
      final config = AdConfig(
        waterfall: const [AdNetwork.admob, AdNetwork.unity],
        networks: {AdNetwork.admob: netConfig()},
      );

      final result = await UnifiedAds.init(config, adapters: [admob]);

      expect(result.error?.code, AdErrorCode.invalidConfig);
      expect(result.error?.attempts, hasLength(1));
      expect(admob.initializeCalls, 0);
      expect(UnifiedAds.isInitialized, isFalse);
    },
  );

  test('re-init disposes the previous session', () async {
    final first = FakeAdNetworkAdapter(AdNetwork.admob);
    final second = FakeAdNetworkAdapter(AdNetwork.admob);

    await UnifiedAds.init(configFor([AdNetwork.admob]), adapters: [first]);
    await UnifiedAds.init(configFor([AdNetwork.admob]), adapters: [second]);

    expect(first.disposeCalls, 1);
    expect(second.disposeCalls, 0);
    expect(UnifiedAds.isInitialized, isTrue);

    await UnifiedAds.dispose();
    expect(second.disposeCalls, 1);
    expect(UnifiedAds.isInitialized, isFalse);
  });

  test('concurrent init calls are serialized; the last one wins', () async {
    final first = FakeAdNetworkAdapter(AdNetwork.admob)
      ..initDelay = const Duration(milliseconds: 30);
    final second = FakeAdNetworkAdapter(AdNetwork.unity);

    final results = await Future.wait([
      UnifiedAds.init(configFor([AdNetwork.admob]), adapters: [first]),
      UnifiedAds.init(configFor([AdNetwork.unity]), adapters: [second]),
    ]);

    expect(results[0].ready, {AdNetwork.admob});
    expect(results[1].ready, {AdNetwork.unity});
    expect(first.disposeCalls, 1);
    expect(UnifiedAds.readyNetworks, {AdNetwork.unity});
  });

  test('warns when test mode cannot be forced in code', () async {
    final records = <AdsLogRecord>[];
    UnifiedAds.logger = AdsLogger(
      level: AdsLogLevel.warning,
      sink: records.add,
    );
    final inmobi = FakeAdNetworkAdapter(
      AdNetwork.inmobi,
      testModeSupport: TestModeSupport.none,
    );

    await UnifiedAds.init(configFor([AdNetwork.inmobi]), adapters: [inmobi]);

    expect(
      records.where(
        (r) => r.network == AdNetwork.inmobi && r.message.contains('testMode'),
      ),
      hasLength(1),
    );
  });

  test('updateConsent reaches every adapter and later sessions', () async {
    final admob = FakeAdNetworkAdapter(AdNetwork.admob);
    await UnifiedAds.init(configFor([AdNetwork.admob]), adapters: [admob]);

    await UnifiedAds.updateConsent(const ConsentState(ccpaOptOut: true));

    expect(admob.consents.last.ccpaOptOut, isTrue);
    expect(UnifiedAds.consent.ccpaOptOut, isTrue);

    final next = FakeAdNetworkAdapter(AdNetwork.admob);
    await UnifiedAds.init(configFor([AdNetwork.admob]), adapters: [next]);
    expect(next.consents.single.ccpaOptOut, isTrue);
  });

  test(
    'gatherConsent applies the provider result and survives failures',
    () async {
      final admob = FakeAdNetworkAdapter(AdNetwork.admob);
      await UnifiedAds.init(configFor([AdNetwork.admob]), adapters: [admob]);

      final state = await UnifiedAds.gatherConsent(
        _Provider(const ConsentState(gdprApplies: true, consentGiven: false)),
      );
      expect(state.consentGiven, isFalse);
      expect(admob.consents.last.consentGiven, isFalse);

      final kept = await UnifiedAds.gatherConsent(_Provider(null));
      expect(kept, state);
    },
  );

  test('gatherConsent keeps app-level coppa and CCPA signals', () async {
    await UnifiedAds.updateConsent(
      const ConsentState(coppa: true, ccpaOptOut: true),
    );

    final state = await UnifiedAds.gatherConsent(
      _Provider(const ConsentState(gdprApplies: false)),
    );

    expect(state.gdprApplies, isFalse);
    expect(state.coppa, isTrue);
    expect(state.ccpaOptOut, isTrue);
  });
}

class _Provider extends ConsentProvider {
  _Provider(this.state);

  final ConsentState? state;

  @override
  Future<ConsentState> gather({bool forceForm = false}) async =>
      state ?? (throw StateError('CMP unavailable'));

  @override
  Future<bool> canRequestAds() async => true;

  @override
  Future<void> showPrivacyOptions() async {}
}
