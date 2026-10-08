// Drives the real example UI on a device: init with the public test IDs, then
// for each network tap "Banner" and "Load interstitial" in its card; AdMob's
// interstitial is also shown. Results are printed per network; only AdMob
// (Google demo units always fill) must pass.
//
//   flutter test integration_test/example_app_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_example/main.dart';

Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example app: per-network buttons serve ads on screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DemoApp());

    expect(
      await _waitFor(tester, find.textContaining('Initialized:')),
      isTrue,
      reason: 'init did not finish',
    );
    final results = <String, String>{};
    final scrollable = find.byType(Scrollable).first;

    Future<String> step(
      AdNetwork network,
      Finder card,
      String button,
      String prefix, {
      String done = '(?!loading)',
    }) async {
      final target = find.descendant(of: card, matching: find.text(button));
      await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
      // scrollUntilVisible stops once the button is built (it may still be in
      // the cache extent, under the navigation bar): center it before tapping.
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(target);
      final status = find.descendant(
        of: card,
        matching: find.textContaining(RegExp('^$prefix: $done')),
      );
      if (!await _waitFor(tester, status)) return 'TIMEOUT';
      return (tester.widget<Text>(status.first).data ?? '').substring(
        prefix.length + 2,
      );
    }

    // AdMob last: its interstitial is shown and stays on top of the app.
    for (final network in [
      AdNetwork.facebook,
      AdNetwork.unity,
      AdNetwork.startapp,
      AdNetwork.inmobi,
      AdNetwork.admob,
    ]) {
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      final card = find.byKey(ValueKey('card-${network.id}'));
      await tester.scrollUntilVisible(card, 300, scrollable: scrollable);
      final banner = find.descendant(
        of: card,
        matching: find.widgetWithText(FilledButton, 'Banner'),
      );
      if (tester.widget<FilledButton>(banner).onPressed == null) {
        results[network.id] = 'not ready';
        continue;
      }
      final bannerResult = await step(network, card, 'Banner', 'banner');
      final loadResult = await step(
        network,
        card,
        'Load interstitial',
        'interstitial',
      );
      results[network.id] = 'banner=$bannerResult; interstitial=$loadResult';

      if (network == AdNetwork.admob) {
        expect(bannerResult, startsWith('showing'));
        expect(loadResult, startsWith('ready'));
        final shown = await step(
          network,
          card,
          'Show interstitial',
          'interstitial',
          done: '(showing|closed|show failed)',
        );
        results['admob show'] = shown;
        expect(shown, anyOf(startsWith('showing'), startsWith('closed')));
        // Leave the ad up briefly so it is visible on the device.
        await tester.pump(const Duration(seconds: 3));
      }
    }

    // ignore: avoid_print
    print(
      'EXAMPLE APP RESULTS:\n${results.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}',
    );
  });
}
