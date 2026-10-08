import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

void main() {
  group('AdapterRegistry', () {
    tearDown(AdapterRegistry.instance.clear);

    test('registers, replaces and unregisters adapters', () {
      const first = UnsupportedAdNetworkAdapter(
        network: AdNetwork.facebook,
        reason: 'a',
      );
      const second = UnsupportedAdNetworkAdapter(
        network: AdNetwork.facebook,
        reason: 'b',
      );
      final registry = AdapterRegistry.instance..register(first);
      expect(registry.adapterFor(AdNetwork.facebook), same(first));

      registry.register(second);
      expect(registry.adapters, [second]);
      expect(registry.isRegistered(AdNetwork.facebook), isTrue);

      registry.unregister(AdNetwork.facebook);
      expect(registry.isRegistered(AdNetwork.facebook), isFalse);
    });
  });

  group('UnsupportedAdNetworkAdapter', () {
    const stub = UnsupportedAdNetworkAdapter(
      network: AdNetwork.facebook,
      reason: 'bidding only',
    );

    test('fails every operation with unsupportedNetwork', () async {
      final init = await stub.initialize(const NetworkConfig(), testMode: true);
      final load = await stub.load(AdFormat.interstitial, 'x');

      for (final error in [init.errorOrNull, load.errorOrNull]) {
        expect(error?.code, AdErrorCode.unsupportedNetwork);
        expect(error?.network, AdNetwork.facebook);
        expect(error?.message, 'bidding only');
      }
      expect(stub.supportedFormats, isEmpty);
      expect(await stub.events.isEmpty, isTrue);
    });
  });

  group('AdsLogger', () {
    test('filters by level and is silent by default', () {
      final records = <AdsLogRecord>[];
      final logger = AdsLogger(level: AdsLogLevel.info, sink: records.add)
        ..debug('hidden')
        ..info('shown', network: AdNetwork.admob)
        ..error('bad', error: StateError('x'));

      expect(records.map((r) => r.message), ['shown', 'bad']);
      expect(records.first.toString(), '[unified_ads] INFO [admob] shown');
      expect(logger.isEnabled(AdsLogLevel.verbose), isFalse);
      expect(AdsLogger.silent.isEnabled(AdsLogLevel.error), isFalse);
      expect(AdsLogger.current, same(AdsLogger.silent));
    });

    test('swallows sink exceptions', () {
      final logger = AdsLogger(
        level: AdsLogLevel.verbose,
        sink: (_) => throw StateError('sink broke'),
      );
      expect(() => logger.error('x'), returnsNormally);
    });

    test('maskId hides the middle of identifiers', () {
      expect(maskId('ca-app-pub-3940256099942544/1033173712'), 'ca-a…3712');
      expect(maskId('short'), '****');
      expect(maskId(null), '<none>');
    });
  });
}
