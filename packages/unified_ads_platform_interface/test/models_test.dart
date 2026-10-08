import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

void main() {
  group('enums', () {
    test('parse their stable ids', () {
      expect(AdNetwork.tryParse('ironsource'), AdNetwork.ironsource);
      expect(AdNetwork.tryParse('meta'), isNull, reason: 'renamed to facebook');
      expect(AdNetwork.tryParse('facebook'), AdNetwork.facebook);
      expect(
        AdFormat.tryParse('rewardedInterstitial'),
        AdFormat.rewardedInterstitial,
      );
      expect(AdFormat.banner.isFullScreen, isFalse);
      expect(AdFormat.rewardedInterstitial.isRewarded, isTrue);
      expect(TestModeSupport.testDevices.canForceTestAds, isTrue);
      expect(TestModeSupport.testSuiteOnly.canForceTestAds, isFalse);
    });
  });

  group('AdError', () {
    test('has value equality and readable output', () {
      const a = AdError(
        code: AdErrorCode.noFill,
        message: 'none',
        network: AdNetwork.admob,
        nativeCode: '3',
      );
      expect(a, a.copyWith());
      expect(a.toString(), 'AdError(noFill, admob, native: 3): none');
    });

    test('fromException wraps unknown errors and keeps AdErrors', () {
      final wrapped = AdError.fromException(
        StateError('x'),
        network: AdNetwork.unity,
      );
      expect(wrapped.code, AdErrorCode.internal);
      expect(wrapped.network, AdNetwork.unity);

      const original = AdError(code: AdErrorCode.timeout, message: 't');
      expect(
        AdError.fromException(original, network: AdNetwork.inmobi).network,
        AdNetwork.inmobi,
      );
    });
  });

  test('AdResult exposes value and error', () {
    const ok = AdSuccess<int>(1);
    const fail = AdFailure<int>(
      AdError(code: AdErrorCode.timeout, message: 't'),
    );
    expect(ok.isSuccess, isTrue);
    expect(ok.valueOrNull, 1);
    expect(fail.valueOrNull, isNull);
    expect(fail.errorOrNull?.code, AdErrorCode.timeout);
  });

  group('NetworkConfig', () {
    const config = NetworkConfig(
      appId: 'app',
      bannerAdUnitId: 'b',
      rewardedAdUnitId: 'r',
      enabledFormats: {AdFormat.banner},
    );

    test('maps formats to unit IDs and enabled formats', () {
      expect(config.adUnitIdFor(AdFormat.banner), 'b');
      expect(config.adUnitIdFor(AdFormat.appOpen), isNull);
      expect(config.isFormatEnabled(AdFormat.banner), isTrue);
      expect(config.isFormatEnabled(AdFormat.rewarded), isFalse);
      expect(const NetworkConfig().isFormatEnabled(AdFormat.rewarded), isTrue);
    });

    test('has value equality', () {
      expect(config, config.copyWith());
      expect(config == config.copyWith(appId: 'other'), isFalse);
    });
  });

  group('AdConfig', () {
    test('effectiveWaterfall uses the explicit order or enum order', () {
      const explicit = AdConfig(
        waterfall: [AdNetwork.inmobi, AdNetwork.admob],
        networks: {
          AdNetwork.admob: NetworkConfig(),
          AdNetwork.inmobi: NetworkConfig(),
        },
      );
      expect(explicit.effectiveWaterfall, [AdNetwork.inmobi, AdNetwork.admob]);

      const implicit = AdConfig(
        networks: {
          AdNetwork.inmobi: NetworkConfig(),
          AdNetwork.admob: NetworkConfig(),
        },
      );
      expect(implicit.effectiveWaterfall, [AdNetwork.admob, AdNetwork.inmobi]);
    });

    test('per-network testMode overrides the global flag', () {
      const config = AdConfig(
        testMode: true,
        networks: {
          AdNetwork.admob: NetworkConfig(testMode: false),
          AdNetwork.unity: NetworkConfig(),
        },
      );
      expect(config.isTestMode(AdNetwork.admob), isFalse);
      expect(config.isTestMode(AdNetwork.unity), isTrue);
      expect(config, config.copyWith());
    });
  });

  group('BannerSize', () {
    test('fills the width of adaptive sizes only', () {
      const adaptive = BannerSize.adaptiveInline(maxHeight: 90);
      expect(adaptive.isAdaptive, isTrue);
      expect(adaptive.withWidth(360).width, 360);
      expect(adaptive.withWidth(360).maxHeight, 90);
      expect(BannerSize.standard.withWidth(360), BannerSize.standard);
      expect(BannerSize.mediumRectangle.fallbackHeight, 250);
      expect(adaptive.fallbackHeight, 50);
      expect(BannerSize.standard.toMap()['type'], 'standard');
    });
  });

  test('PlatformValue picks the platform value', () {
    expect(
      PlatformValue.select(
        android: 'a',
        ios: 'i',
        platform: TargetPlatform.iOS,
      ),
      'i',
    );
    expect(
      PlatformValue.select(
        android: 'a',
        ios: 'i',
        platform: TargetPlatform.android,
      ),
      'a',
    );
  });

  test('PreloadPolicy only covers full-screen formats it lists', () {
    const policy = PreloadPolicy();
    expect(policy.isEnabledFor(AdFormat.interstitial), isTrue);
    expect(policy.isEnabledFor(AdFormat.appOpen), isFalse);
    expect(PreloadPolicy.none.isEnabledFor(AdFormat.rewarded), isFalse);
  });

  test('ConsentState copyWith and equality', () {
    const state = ConsentState(gdprApplies: true);
    expect(state.copyWith(coppa: true).coppa, isTrue);
    expect(state, const ConsentState(gdprApplies: true));
    expect(ConsentState.unknown.coppa, isFalse);
  });
}
