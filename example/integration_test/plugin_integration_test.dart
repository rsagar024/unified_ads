// Runs on a device or emulator:
//   flutter test integration_test/plugin_integration_test.dart -d <device-id>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_example/main.dart';

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdMob end to end with Google test ad units', (tester) async {
    UnifiedAds.logger = const AdsLogger.console(level: AdsLogLevel.debug);
    final events = <String>[];
    final sub = UnifiedAds.events.listen(
      (e) => events.add('${e.format.id}:${e.kind}'),
    );

    final result = await UnifiedAds.init(
      AdConfig(
        testMode: true,
        preload: PreloadPolicy.none,
        networks: {AdNetwork.admob: admobTestConfig},
      ),
    );
    expect(result.ready, contains(AdNetwork.admob), reason: '$result');

    // Banner: a real native AdView rendered through the platform view.
    final banner = BannerAd();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: UnifiedBannerWidget(ad: banner, anchored: true),
          ),
        ),
      ),
    );
    await _waitFor(
      tester,
      () =>
          banner.state != BannerAdState.idle &&
          banner.state != BannerAdState.loading,
    );
    expect(banner.state, BannerAdState.loaded, reason: '${banner.error}');
    expect(banner.servedBy, AdNetwork.admob);
    expect(banner.adSize, isNotNull);

    // Rewarded: load only (showing would need a user to close it).
    final rewarded = RewardedAd();
    final rewardedLoad = await rewarded.load();
    expect(
      rewardedLoad.isSuccess,
      isTrue,
      reason: '${rewardedLoad.errorOrNull}',
    );
    expect(rewarded.servedBy, AdNetwork.admob);

    // Rewarded interstitial and app open (Phase 7): load only.
    final rewardedInterstitial = RewardedInterstitialAd();
    final riLoad = await rewardedInterstitial.load();
    expect(riLoad.isSuccess, isTrue, reason: '${riLoad.errorOrNull}');
    expect(rewardedInterstitial.servedBy, AdNetwork.admob);
    final appOpen = AppOpenAd();
    final appOpenLoad = await appOpen.load();
    expect(appOpenLoad.isSuccess, isTrue, reason: '${appOpenLoad.errorOrNull}');
    expect(appOpen.servedBy, AdNetwork.admob);

    // Interstitial: load and present.
    var shown = false;
    final interstitial = InterstitialAd(onShown: (_) => shown = true);
    final load = await interstitial.load();
    expect(load.isSuccess, isTrue, reason: '${load.errorOrNull}');
    final show = await interstitial.show();
    expect(show.isSuccess, isTrue, reason: '${show.errorOrNull}');
    await _waitFor(tester, () => shown, timeout: const Duration(seconds: 10));
    expect(shown, isTrue);

    await sub.cancel();
    expect(
      events,
      containsAll(<String>[
        'banner:bannerSized',
        'banner:loaded',
        'rewarded:loaded',
        'rewardedInterstitial:loaded',
        'appOpen:loaded',
        'interstitial:loaded',
        'interstitial:shown',
      ]),
    );
  });
}
