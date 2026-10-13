// Helpers shared by the integration tests. Self-contained (imports only
// unified_ads and flutter_test) so tool/ios_sim_smoke.sh can copy it into
// scratch apps.
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/unified_ads.dart';

/// Formats [e] for a test log line.
String describeError(AdError? e) => e == null
    ? 'unknown error'
    : '${e.code.name}${e.nativeCode == null ? '' : ' (native ${e.nativeCode})'}: '
          '${e.message}';

/// Pumps [tester] until [done] returns true or [timeout] elapses.
///
/// Uses real time (integration tests run on a device), pumping every 250 ms
/// so platform views and callbacks keep being processed.
Future<void> waitFor(
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
