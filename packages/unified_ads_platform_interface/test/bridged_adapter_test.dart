import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

class _Bridge extends BridgedAdNetworkAdapter {
  int listenCalls = 0;
  PlatformException? failWith;
  final List<String> calls = [];

  @override
  AdNetwork get network => AdNetwork.unity;

  @override
  Set<AdFormat> get supportedFormats => const {
    AdFormat.banner,
    AdFormat.interstitial,
  };

  @override
  TestModeSupport get testModeSupport => TestModeSupport.flag;

  @override
  String get bannerViewType => 'test/banner';

  @override
  Map<String, Object?> bannerCreationParams(BannerRequest request) => const {};

  @override
  void listenToNativeEvents() => listenCalls++;

  Future<T> _call<T>(String name, T value) async {
    calls.add(name);
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<void> nativeInitialize(
    NetworkConfig config, {
    required bool testMode,
  }) => _call('init', null);

  @override
  Future<String> nativeLoad(AdFormat format, String adUnitId) =>
      _call('load', 'ad-1');

  @override
  Future<void> nativeShow(String adId) => _call('show', null);

  @override
  Future<void> nativeDestroy(String adId) => _call('destroy', null);

  @override
  Future<void> nativeApplyConsent(ConsentState state) => _call('consent', null);

  @override
  Future<void> nativeDispose() => _call('dispose', null);
}

void main() {
  late _Bridge bridge;
  setUp(() => bridge = _Bridge());

  test('listens once and maps init failures', () async {
    await bridge.initialize(const NetworkConfig(), testMode: false);
    bridge.failWith = PlatformException(code: 'bogus', message: 'x');
    final error = (await bridge.initialize(
      const NetworkConfig(),
      testMode: false,
    )).errorOrNull;

    expect(bridge.listenCalls, 1);
    expect(error?.code, AdErrorCode.initializationFailed, reason: 'fallback');
    expect(error?.network, AdNetwork.unity);
  });

  test('tracks readiness and refuses unsupported formats natively', () async {
    final handle = (await bridge.load(AdFormat.interstitial, 'u')).valueOrNull!;
    expect(bridge.isReady(handle), isTrue);
    expect((await bridge.show(handle)).isSuccess, isTrue);
    expect(bridge.isReady(handle), isFalse);
    expect((await bridge.show(handle)).errorOrNull?.code, AdErrorCode.notReady);

    final rewarded = await bridge.load(AdFormat.rewarded, 'u');
    expect(rewarded.errorOrNull?.code, AdErrorCode.unsupportedFormat);
    expect(bridge.calls.where((c) => c == 'load'), hasLength(1));
  });

  test('swallows failures of fire-and-forget calls', () async {
    bridge.failWith = PlatformException(code: 'internal');
    final handle = AdHandle(
      id: 'x',
      network: AdNetwork.unity,
      format: AdFormat.interstitial,
      adUnitId: 'u',
      loadedAt: DateTime(2026),
    );

    await expectLater(bridge.destroy(handle), completes);
    await expectLater(bridge.applyConsent(ConsentState.unknown), completes);
    await expectLater(bridge.dispose(), completes);
  });

  test(
    'emitNativeEvent translates, releases closed ads and drops junk',
    () async {
      final handle = (await bridge.load(
        AdFormat.interstitial,
        'u',
      )).valueOrNull!;
      final events = <AdEvent>[];
      final sub = bridge.events.listen(events.add);

      bridge
        ..emitNativeEvent(
          kind: 'bannerSized',
          adId: 'b',
          format: 'banner',
          width: 320,
          height: 50,
        )
        ..emitNativeEvent(
          kind: 'failedToLoad',
          adId: 'b',
          format: 'banner',
          errorCode: 'noFill',
          nativeCode: '204',
        )
        ..emitNativeEvent(
          kind: 'closed',
          adId: handle.id,
          format: 'interstitial',
        )
        ..emitNativeEvent(kind: 'teleported', adId: 'x', format: 'banner')
        ..emitNativeEvent(kind: 'loaded', adId: 'x', format: 'hologram');
      await pumpEventQueue();
      await sub.cancel();

      expect(events, hasLength(3));
      expect((events[0] as BannerSized).height, 50);
      expect((events[1] as AdFailedToLoad).error.code, AdErrorCode.noFill);
      expect(events[2], isA<AdClosed>());
      expect(bridge.isReady(handle), isFalse);
    },
  );

  test('errorCodeFromName falls back for unknown names', () {
    expect(
      BridgedAdNetworkAdapter.errorCodeFromName(
        'timeout',
        AdErrorCode.internal,
      ),
      AdErrorCode.timeout,
    );
    expect(
      BridgedAdNetworkAdapter.errorCodeFromName('nope', AdErrorCode.internal),
      AdErrorCode.internal,
    );
  });
}
