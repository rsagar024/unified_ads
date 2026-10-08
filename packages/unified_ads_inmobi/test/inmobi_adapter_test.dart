import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_inmobi/src/messages.g.dart';
import 'package:unified_ads_inmobi/unified_ads_inmobi.dart';

class FakeHost extends InmobiHostApi {
  InitRequest? initRequest;
  PlatformException? initError;
  final List<(AdFormatMessage, String)> loads = [];
  PlatformException? loadError;
  int _counter = 0;
  final List<String> shown = [];
  PlatformException? showError;
  final List<String> destroyed = [];
  final List<ConsentMessage> consents = [];
  int disposeCalls = 0;

  @override
  Future<void> initialize(InitRequest request) async {
    initRequest = request;
    if (initError != null) throw initError!;
  }

  @override
  Future<String> load(AdFormatMessage format, String adUnitId) async {
    loads.add((format, adUnitId));
    if (loadError != null) throw loadError!;
    return 'inmobi-${++_counter}';
  }

  @override
  Future<void> show(String adId) async {
    if (showError != null) throw showError!;
    shown.add(adId);
  }

  @override
  Future<void> destroy(String adId) async => destroyed.add(adId);

  @override
  Future<void> applyConsent(ConsentMessage consent) async =>
      consents.add(consent);

  @override
  Future<void> dispose() async => disposeCalls++;
}

Future<void> sendNativeEvent(AdEventMessage event) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'dev.flutter.pigeon.unified_ads_inmobi.InmobiEventsApi.onAdEvent',
          InmobiEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[event]),
          (_) {},
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHost host;
  late InmobiAdapter adapter;

  setUp(() {
    host = FakeHost();
    adapter = InmobiAdapter(hostApi: host);
  });

  tearDown(() async {
    await UnifiedAds.dispose();
    AdapterRegistry.instance.clear();
  });

  test('registerWith registers the adapter', () {
    InmobiAdapter.registerWith();
    expect(
      AdapterRegistry.instance.adapterFor(AdNetwork.inmobi),
      isA<InmobiAdapter>(),
    );
  });

  test('declares formats, test-mode support and the banner view type', () {
    expect(adapter.network, AdNetwork.inmobi);
    expect(adapter.supportedFormats, {
      AdFormat.banner,
      AdFormat.interstitial,
      AdFormat.rewarded,
    });
    expect(adapter.testModeSupport, TestModeSupport.none);
    expect(adapter.requiresAdUnitId, isTrue);
    expect(
      adapter.bannerViewType,
      'dev.arovyx.plugin.unifiedads/inmobi/banner',
    );
  });

  test('initialize forwards credentials, test mode and extras', () async {
    final result = await adapter.initialize(
      const NetworkConfig(
        appId: 'app-key',
        testDeviceIds: ['device'],
        extras: {'userId': 'user-1'},
      ),
      testMode: true,
    );

    expect(result.isSuccess, isTrue);
    expect(host.initRequest?.appId, 'app-key');
    expect(host.initRequest?.testMode, isTrue);
    expect(host.initRequest?.testDeviceIds, ['device']);
    expect(host.initRequest?.userId, 'user-1');
  });

  test('initialize maps native errors', () async {
    host.initError = PlatformException(
      code: 'invalidConfig',
      message: 'bad key',
      details: '42',
    );

    final error = (await adapter.initialize(
      const NetworkConfig(appId: 'x'),
      testMode: false,
    )).errorOrNull;

    expect(error?.code, AdErrorCode.invalidConfig);
    expect(error?.nativeCode, '42');
    expect(error?.network, AdNetwork.inmobi);
  });

  test(
    'loads full-screen ads; banners are not loaded as full-screen',
    () async {
      final handle = (await adapter.load(
        AdFormat.rewarded,
        'unit',
      )).valueOrNull!;
      expect(host.loads.single, (AdFormatMessage.rewarded, 'unit'));
      expect(adapter.isReady(handle), isTrue);

      final banner = await adapter.load(AdFormat.banner, 'unit');
      expect(banner.errorOrNull?.code, AdErrorCode.unsupportedFormat);
      expect(host.loads, hasLength(1));
    },
  );

  test('load, show and destroy map errors and track readiness', () async {
    host.loadError = PlatformException(code: 'noFill', details: '1');
    expect(
      (await adapter.load(AdFormat.interstitial, 'u')).errorOrNull?.code,
      AdErrorCode.noFill,
    );
    host.loadError = null;

    final first = (await adapter.load(AdFormat.interstitial, 'u')).valueOrNull!;
    expect((await adapter.show(first)).isSuccess, isTrue);
    expect(adapter.isReady(first), isFalse);

    final second = (await adapter.load(
      AdFormat.interstitial,
      'u',
    )).valueOrNull!;
    host.showError = PlatformException(code: 'noActivity');
    expect(
      (await adapter.show(second)).errorOrNull?.code,
      AdErrorCode.noActivity,
    );

    final third = (await adapter.load(AdFormat.interstitial, 'u')).valueOrNull!;
    await adapter.destroy(third);
    expect(host.destroyed, [third.id]);
  });

  test('banner params, consent and dispose reach the native side', () async {
    final params = adapter.bannerCreationParams(
      const BannerRequest(
        adId: 'b1',
        adUnitId: 'unit',
        size: BannerSize.standard,
        testMode: false,
      ),
    );
    expect(params['adId'], 'b1');
    expect((params['size']! as Map<String, Object?>)['type'], 'standard');

    await adapter.applyConsent(
      const ConsentState(gdprApplies: true, coppa: true),
    );
    await adapter.dispose();
    expect(host.consents.single.coppa, isTrue);
    expect(host.disposeCalls, 1);
  });

  test(
    'native events become AdEvents; rewards without amount use defaults',
    () async {
      await adapter.initialize(
        const NetworkConfig(
          appId: 'x',
          extras: {'rewardAmount': 5, 'rewardType': 'gems'},
        ),
        testMode: false,
      );
      final events = <AdEvent>[];
      final sub = adapter.events.listen(events.add);

      await sendNativeEvent(
        AdEventMessage(
          kind: AdEventKind.earnedReward,
          adId: 'r1',
          format: AdFormatMessage.rewarded,
        ),
      );
      await sendNativeEvent(
        AdEventMessage(
          kind: AdEventKind.failedToLoad,
          adId: 'b1',
          format: AdFormatMessage.banner,
          errorCode: 'noFill',
          nativeCode: '7',
        ),
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(
        (events[0] as AdEarnedReward).reward,
        const RewardItem(amount: 5, type: 'gems'),
      );
      final failed = events[1] as AdFailedToLoad;
      expect(failed.error.code, AdErrorCode.noFill);
      expect(failed.error.nativeCode, '7');
    },
  );

  test('works end to end through UnifiedAds', () async {
    final result = await UnifiedAds.init(
      const AdConfig(
        preload: PreloadPolicy.none,
        networks: {
          AdNetwork.inmobi: NetworkConfig(
            appId: 'app-id',
            interstitialAdUnitId: '1234567890',
          ),
        },
      ),
      adapters: [adapter],
    );
    expect(result.ready, {AdNetwork.inmobi});

    var closed = false;
    final ad = InterstitialAd(onClosed: (_) => closed = true);
    expect((await ad.load()).isSuccess, isTrue);
    expect(ad.servedBy, AdNetwork.inmobi);
    expect((await ad.show()).isSuccess, isTrue);
    await sendNativeEvent(
      AdEventMessage(
        kind: AdEventKind.closed,
        adId: 'inmobi-1',
        format: AdFormatMessage.interstitial,
      ),
    );
    await pumpEventQueue();
    expect(closed, isTrue);
  });
}
