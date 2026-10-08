// Device smoke test for any network, driven by --dart-define so credentials
// are never stored in the repository:
//
//   flutter test integration_test/network_smoke_test.dart -d <device> \
//     --dart-define=NETWORK=applovin --dart-define=APP_ID=<key> \
//     --dart-define=BANNER_ID=<id> --dart-define=INTERSTITIAL_ID=<id> \
//     --dart-define=REWARDED_ID=<id> [--dart-define=TEST_MODE=false]
//
// Every step runs even if an earlier one fails; a summary is printed and the
// test fails at the end if any step failed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unified_ads/unified_ads.dart';

const _network = String.fromEnvironment('NETWORK');
const _appId = String.fromEnvironment('APP_ID');
const _bannerId = String.fromEnvironment('BANNER_ID');
const _interstitialId = String.fromEnvironment('INTERSTITIAL_ID');
const _rewardedId = String.fromEnvironment('REWARDED_ID');
const _testMode = bool.fromEnvironment('TEST_MODE', defaultValue: true);

String? _nonEmpty(String value) => value.isEmpty ? null : value;

String _describe(AdError? e) => e == null
    ? 'unknown error'
    : '${e.code.name}${e.nativeCode == null ? '' : ' (native ${e.nativeCode})'}: '
          '${e.message}';

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
  final network = AdNetwork.tryParse(_network);

  testWidgets(
    '$_network smoke test: init, banner, rewarded load, interstitial show',
    skip: network == null,
    (tester) async {
      UnifiedAds.logger = const AdsLogger.console(level: AdsLogLevel.debug);
      final results = <String, String>{};
      final failures = <String>[];
      void record(String step, {required bool ok, String detail = 'ok'}) {
        results[step] = ok ? 'PASS' : 'FAIL $detail';
        if (!ok) failures.add(step);
      }

      final events = <String>[];
      final sub = UnifiedAds.events.listen(
        (e) => events.add('${e.format.id}:${e.kind}'),
      );

      final init = await UnifiedAds.init(
        AdConfig(
          testMode: _testMode,
          preload: PreloadPolicy.none,
          loadTimeout: const Duration(seconds: 30),
          networks: {
            network!: NetworkConfig(
              appId: _appId,
              bannerAdUnitId: _nonEmpty(_bannerId),
              interstitialAdUnitId: _nonEmpty(_interstitialId),
              rewardedAdUnitId: _nonEmpty(_rewardedId),
            ),
          },
        ),
      );
      final initError =
          init.failed[network] ?? init.skipped[network] ?? init.error;
      record(
        'init',
        ok: init.ready.contains(network),
        detail: _describe(initError),
      );

      if (init.ready.contains(network)) {
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
              banner.state == BannerAdState.loaded ||
              banner.state == BannerAdState.failed,
          timeout: const Duration(seconds: 45),
        );
        record(
          'banner',
          ok: banner.state == BannerAdState.loaded,
          detail: banner.state == BannerAdState.failed
              ? _describe(banner.error)
              : 'still ${banner.state.name}',
        );

        final rewarded = RewardedAd();
        final rewardedLoad = await rewarded.load();
        record(
          'rewarded load',
          ok: rewardedLoad.isSuccess,
          detail: _describe(rewardedLoad.errorOrNull),
        );

        var shown = false;
        final interstitial = InterstitialAd(onShown: (_) => shown = true);
        final load = await interstitial.load();
        record(
          'interstitial load',
          ok: load.isSuccess,
          detail: _describe(load.errorOrNull),
        );
        if (load.isSuccess) {
          final show = await interstitial.show();
          await _waitFor(
            tester,
            () => shown,
            timeout: const Duration(seconds: 10),
          );
          record(
            'interstitial show',
            ok: show.isSuccess && shown,
            detail: show.isSuccess
                ? 'no shown event within 10 s'
                : _describe(show.errorOrNull),
          );
        }
      }

      await sub.cancel();
      debugPrint('==== SMOKE TEST SUMMARY: $_network ====');
      results.forEach((step, result) => debugPrint('  $step: $result'));
      debugPrint('  events: $events');
      debugPrint('==== END SUMMARY ====');
      expect(failures, isEmpty, reason: 'failed steps: $failures');
    },
  );
}
