import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_ads/testing.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_example/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows a waterfall card and one card per network', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoApp(autoInit: false));

    expect(find.text('Waterfall (auto)'), findsOneWidget);
    for (final network in AdNetwork.values) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('card-${network.id}')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(ValueKey('card-${network.id}')), findsOneWidget);
    }
  });

  testWidgets('loading before init reports notInitialized', (tester) async {
    await tester.pumpWidget(const DemoApp(autoInit: false));

    await tester.tap(find.text('Load interstitial').first);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('notInitialized'), findsOneWidget);

    await tester.tap(find.text('Log'));
    await tester.pump();
    expect(find.textContaining('notInitialized'), findsWidgets);
  });

  testWidgets('format buttons follow each adapter\'s supportedFormats', (
    tester,
  ) async {
    AdapterRegistry.instance
      ..register(
        FakeAdNetworkAdapter(
          AdNetwork.admob,
          supportedFormats: AdFormat.values.toSet(),
        ),
      )
      ..register(FakeAdNetworkAdapter(AdNetwork.unity));
    addTearDown(AdapterRegistry.instance.clear);
    await tester.pumpWidget(const DemoApp(autoInit: false));

    Finder inCard(String network, String text) => find.descendant(
      of: find.byKey(ValueKey('card-$network')),
      matching: find.text(text),
    );
    // The waterfall card offers every full-screen format.
    expect(inCard('waterfall', 'Load rewarded interstitial'), findsOneWidget);
    expect(inCard('waterfall', 'Load app open'), findsOneWidget);

    for (final network in ['admob', 'unity']) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('card-$network')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    expect(inCard('admob', 'Load rewarded interstitial'), findsOneWidget);
    expect(inCard('admob', 'Load app open'), findsOneWidget);
    expect(inCard('unity', 'Load rewarded'), findsOneWidget);
    expect(inCard('unity', 'Load rewarded interstitial'), findsNothing);
    expect(inCard('unity', 'Load app open'), findsNothing);
  });

  testWidgets('network buttons stay disabled until the network is ready', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoApp(autoInit: false));

    final admobCard = find.byKey(const ValueKey('card-admob'));
    await tester.scrollUntilVisible(
      admobCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final banner = tester.widget<FilledButton>(
      find.descendant(
        of: admobCard,
        matching: find.widgetWithText(FilledButton, 'Banner'),
      ),
    );
    expect(banner.onPressed, isNull);
  });
}
