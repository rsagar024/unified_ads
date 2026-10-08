import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/testing.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

void main() {
  late FakeAdNetworkAdapter admob;
  late FakeAdNetworkAdapter unity;

  setUp(() {
    admob = FakeAdNetworkAdapter(AdNetwork.admob);
    unity = FakeAdNetworkAdapter(
      AdNetwork.unity,
      bannerSize: const Size(360, 57),
    );
  });
  tearDown(resetAll);

  Future<void> init({Duration timeout = const Duration(milliseconds: 200)}) =>
      UnifiedAds.init(
        configFor([AdNetwork.admob, AdNetwork.unity], loadTimeout: timeout),
        adapters: [admob, unity],
      );

  group('BannerAd', () {
    test('fails with notInitialized before init', () async {
      final ad = BannerAd();
      final result = await ad.load();
      expect(result.errorOrNull?.code, AdErrorCode.notInitialized);
      expect(ad.state, BannerAdState.failed);
      ad.dispose();
    });

    test('loads from the first network and resolves the size', () async {
      await init();
      var loaded = 0;
      final ad = BannerAd(onLoaded: (_) => loaded++);

      final result = await ad.load(width: 360);

      expect(result.isSuccess, isTrue);
      expect(ad.state, BannerAdState.loaded);
      expect(ad.servedBy, AdNetwork.admob);
      expect(ad.adSize, const Size(320, 50));
      expect(ad.current?.viewType, 'fake/admob/banner');
      expect(loaded, 1);
      final request = admob.bannerRequests.single;
      expect(request.size.width, 360, reason: 'adaptive width filled in');
      expect(request.adUnitId, '103');
      expect(request.testMode, isTrue);
      ad.dispose();
    });

    test('falls back to the next network when one fails', () async {
      admob.bannerError = noFill;
      await init();
      final ad = BannerAd();

      await ad.load(width: 360);

      expect(ad.servedBy, AdNetwork.unity);
      expect(ad.adSize, const Size(360, 57));
      ad.dispose();
    });

    test('times out a silent network and tries the next', () async {
      admob.respondToBanners = false;
      await init(timeout: const Duration(milliseconds: 30));
      final ad = BannerAd();

      await ad.load();

      expect(ad.servedBy, AdNetwork.unity);
      ad.dispose();
    });

    test('reports an aggregated error when every network fails', () async {
      admob.bannerError = noFill;
      unity.bannerError = noFill;
      await init();
      AdError? reported;
      final ad = BannerAd(onFailedToLoad: (_, e) => reported = e);

      final result = await ad.load();

      expect(ad.state, BannerAdState.failed);
      expect(result.errorOrNull?.attempts, hasLength(2));
      expect(reported, ad.error);
      expect(ad.current, isNull);
      ad.dispose();
    });

    test('forceNetwork limits the banner to one network', () async {
      await init();
      final ad = BannerAd(forceNetwork: AdNetwork.unity);

      await ad.load();

      expect(ad.servedBy, AdNetwork.unity);
      expect(admob.bannerRequests, isEmpty);
      ad.dispose();
    });

    test('dispose completes a pending load', () async {
      admob.respondToBanners = false;
      await init();
      final ad = BannerAd();

      final pending = ad.load();
      ad.dispose();

      expect((await pending).errorOrNull?.code, AdErrorCode.notReady);
      expect(ad.state, BannerAdState.disposed);
    });
  });

  group('UnifiedBannerWidget', () {
    setUp(() {
      UnifiedBannerWidget.platformViewBuilder = (context, attempt) =>
          ColoredBox(
            key: Key('native-${attempt.network.id}'),
            color: Colors.green,
          );
    });
    tearDown(() {
      UnifiedBannerWidget.platformViewBuilder = buildBannerPlatformView;
    });

    Future<void> pumpBanner(
      WidgetTester tester,
      BannerAd ad, {
      bool anchored = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [UnifiedBannerWidget(ad: ad, anchored: anchored)],
            ),
          ),
        ),
      );
      await tester.pump(); // post-frame load()
      await tester.pump(); // banner response
    }

    testWidgets('loads on first layout and sizes itself', (tester) async {
      await init();
      final ad = BannerAd();

      await pumpBanner(tester, ad);

      expect(find.byKey(const Key('native-admob')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('native-admob'))),
        const Size(320, 50),
      );
      expect(ad.state, BannerAdState.loaded);
      ad.dispose();
    });

    testWidgets('swaps the native view when falling back', (tester) async {
      admob.bannerError = noFill;
      await init();
      final ad = BannerAd();

      await pumpBanner(tester, ad, anchored: true);
      await tester.pump();

      expect(find.byKey(const Key('native-admob')), findsNothing);
      expect(find.byKey(const Key('native-unity')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('native-unity'))),
        const Size(360, 57),
      );
      expect(find.byType(SafeArea), findsWidgets);
      ad.dispose();
    });

    testWidgets('collapses when every network fails', (tester) async {
      admob.bannerError = noFill;
      unity.bannerError = noFill;
      await init();
      final ad = BannerAd();

      await pumpBanner(tester, ad);
      await tester.pump();

      expect(ad.state, BannerAdState.failed);
      expect(tester.getSize(find.byType(UnifiedBannerWidget)).height, 0);
      ad.dispose();
    });

    testWidgets('survives the ad being disposed while displayed', (
      tester,
    ) async {
      await init();
      final ad = BannerAd();
      await pumpBanner(tester, ad);

      ad.dispose();
      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    });
  });
}
