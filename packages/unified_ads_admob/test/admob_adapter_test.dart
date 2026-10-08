import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads_admob/src/messages.g.dart';
import 'package:unified_ads_admob/unified_ads_admob.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'fake_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHost host;
  late AdmobAdapter adapter;

  setUp(() {
    host = FakeHost();
    adapter = AdmobAdapter(hostApi: host);
  });

  tearDown(AdapterRegistry.instance.clear);

  test('registerWith registers the adapter', () {
    AdmobAdapter.registerWith();
    expect(
      AdapterRegistry.instance.adapterFor(AdNetwork.admob),
      isA<AdmobAdapter>(),
    );
  });

  test('declares formats, test-mode support and the banner view type', () {
    expect(adapter.network, AdNetwork.admob);
    expect(adapter.supportedFormats, {
      AdFormat.banner,
      AdFormat.interstitial,
      AdFormat.rewarded,
      AdFormat.rewardedInterstitial,
      AdFormat.appOpen,
    });
    expect(adapter.testModeSupport, TestModeSupport.testDevices);
    expect(adapter.requiresAdUnitId, isTrue);
    expect(adapter.bannerViewType, 'dev.arovyx.plugin.unifiedads/admob/banner');
  });

  group('initialize', () {
    test('forwards the app ID, test mode and test devices', () async {
      final result = await adapter.initialize(
        const NetworkConfig(appId: 'ca-app-pub-1~2', testDeviceIds: ['dev1']),
        testMode: true,
      );

      expect(result.isSuccess, isTrue);
      expect(host.initRequest?.appId, 'ca-app-pub-1~2');
      expect(host.initRequest?.testMode, isTrue);
      expect(host.initRequest?.testDeviceIds, ['dev1']);
    });

    test('logs whether the opt-in Meta bidding adapter is present', () async {
      final records = <AdsLogRecord>[];
      AdsLogger.current = AdsLogger(
        level: AdsLogLevel.verbose,
        sink: records.add,
      );
      addTearDown(() => AdsLogger.current = AdsLogger.silent);

      host.metaBiddingAdapter =
          'com.google.ads.mediation.facebook.FacebookMediationAdapter';
      await adapter.initialize(const NetworkConfig(), testMode: false);
      host.metaBiddingAdapter = null;
      await adapter.initialize(const NetworkConfig(), testMode: false);

      final messages = [for (final r in records) r.message];
      expect(
        messages,
        contains(
          'Meta bidding adapter detected '
          '(com.google.ads.mediation.facebook.FacebookMediationAdapter)',
        ),
      );
      expect(
        messages,
        contains('Meta bidding adapter not present (opt-in; see doc/setup)'),
      );
    });

    test('maps native errors to AdError', () async {
      host.initError = PlatformException(
        code: 'invalidConfig',
        message: 'Add GADApplicationIdentifier',
      );

      final error = (await adapter.initialize(
        const NetworkConfig(),
        testMode: false,
      )).errorOrNull;

      expect(error?.code, AdErrorCode.invalidConfig);
      expect(error?.network, AdNetwork.admob);
      expect(error?.message, 'Add GADApplicationIdentifier');
    });
  });

  group('full-screen ads', () {
    test('load returns a ready handle', () async {
      final handle = (await adapter.load(
        AdFormat.rewarded,
        'unit',
      )).valueOrNull!;

      expect(handle.id, 'admob-1');
      expect(handle.format, AdFormat.rewarded);
      expect(host.loads.single, (AdFormatMessage.rewarded, 'unit'));
      expect(adapter.isReady(handle), isTrue);
    });

    test('each full-screen format maps to its native format', () async {
      for (final (format, message) in [
        (AdFormat.interstitial, AdFormatMessage.interstitial),
        (AdFormat.rewarded, AdFormatMessage.rewarded),
        (AdFormat.rewardedInterstitial, AdFormatMessage.rewardedInterstitial),
        (AdFormat.appOpen, AdFormatMessage.appOpen),
      ]) {
        host.loads.clear();
        final handle = (await adapter.load(format, 'unit')).valueOrNull!;
        expect(handle.format, format);
        expect(host.loads.single, (message, 'unit'));
      }
    });

    test('banner is not loaded as a full-screen ad', () async {
      final result = await adapter.load(AdFormat.banner, 'unit');

      expect(result.errorOrNull?.code, AdErrorCode.unsupportedFormat);
      expect(host.loads, isEmpty);
    });

    test(
      'load errors keep the native code; unknown codes become internal',
      () async {
        host.loadError = PlatformException(
          code: 'noFill',
          message: 'No fill.',
          details: '3',
        );
        final noFill = (await adapter.load(
          AdFormat.interstitial,
          'u',
        )).errorOrNull;
        expect(noFill?.code, AdErrorCode.noFill);
        expect(noFill?.nativeCode, '3');

        host.loadError = PlatformException(code: 'channel-error');
        final unknown = (await adapter.load(
          AdFormat.interstitial,
          'u',
        )).errorOrNull;
        expect(unknown?.code, AdErrorCode.internal);
      },
    );

    test('show consumes the handle and maps failures', () async {
      final handle = (await adapter.load(
        AdFormat.interstitial,
        'u',
      )).valueOrNull!;

      expect((await adapter.show(handle)).isSuccess, isTrue);
      expect(host.shown, ['admob-1']);
      expect(adapter.isReady(handle), isFalse);
      expect(
        (await adapter.show(handle)).errorOrNull?.code,
        AdErrorCode.notReady,
      );

      final second = (await adapter.load(
        AdFormat.interstitial,
        'u',
      )).valueOrNull!;
      host.showError = PlatformException(code: 'noActivity', message: 'x');
      expect(
        (await adapter.show(second)).errorOrNull?.code,
        AdErrorCode.noActivity,
      );
    });

    test('destroy releases the native ad', () async {
      final handle = (await adapter.load(
        AdFormat.interstitial,
        'u',
      )).valueOrNull!;

      await adapter.destroy(handle);

      expect(host.destroyed, ['admob-1']);
      expect(adapter.isReady(handle), isFalse);
    });
  });

  test('banner creation params carry id, unit, size and test mode', () {
    final params = adapter.bannerCreationParams(
      const BannerRequest(
        adId: 'admob-banner-1',
        adUnitId: 'unit',
        size: BannerSize.adaptiveAnchored(width: 360),
        testMode: true,
      ),
    );

    expect(params['adId'], 'admob-banner-1');
    expect(params['adUnitId'], 'unit');
    expect(params['testMode'], isTrue);
    expect(
      (params['size']! as Map<String, Object?>)['type'],
      'adaptiveAnchored',
    );
    expect((params['size']! as Map<String, Object?>)['width'], 360);
  });

  test('applyConsent and dispose reach the native side', () async {
    await adapter.applyConsent(
      const ConsentState(ccpaOptOut: true, coppa: true),
    );
    await adapter.dispose();

    expect(host.consents.single.ccpaOptOut, isTrue);
    expect(host.consents.single.coppa, isTrue);
    expect(host.disposeCalls, 1);
  });

  group('native events', () {
    setUp(() => adapter.initialize(const NetworkConfig(), testMode: true));

    test('are translated to AdEvents', () async {
      final events = <AdEvent>[];
      final sub = adapter.events.listen(events.add);

      await sendNativeEvent(
        AdEventMessage(
          kind: AdEventKind.earnedReward,
          adId: 'admob-1',
          format: AdFormatMessage.rewarded,
          rewardAmount: 10,
          rewardType: 'coins',
        ),
      );
      await sendNativeEvent(
        AdEventMessage(
          kind: AdEventKind.bannerSized,
          adId: 'b1',
          format: AdFormatMessage.banner,
          width: 360,
          height: 57,
        ),
      );
      await sendNativeEvent(
        AdEventMessage(
          kind: AdEventKind.failedToLoad,
          adId: 'b1',
          format: AdFormatMessage.banner,
          errorCode: 'noFill',
          errorMessage: 'No fill.',
          nativeCode: '3',
        ),
      );
      await pumpEventQueue();
      await sub.cancel();

      final reward = events[0] as AdEarnedReward;
      expect(reward.reward, const RewardItem(amount: 10, type: 'coins'));
      expect(reward.format, AdFormat.rewarded);
      final sized = events[1] as BannerSized;
      expect((sized.width, sized.height), (360, 57));
      final failed = events[2] as AdFailedToLoad;
      expect(failed.error.code, AdErrorCode.noFill);
      expect(failed.error.nativeCode, '3');
      expect(failed.network, AdNetwork.admob);
    });

    test('closed and failedToShow release the handle', () async {
      final handle = (await adapter.load(
        AdFormat.interstitial,
        'u',
      )).valueOrNull!;

      await sendNativeEvent(
        AdEventMessage(
          kind: AdEventKind.closed,
          adId: handle.id,
          format: AdFormatMessage.interstitial,
        ),
      );

      expect(adapter.isReady(handle), isFalse);
    });
  });
}
