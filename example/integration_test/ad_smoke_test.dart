// Interstitial smoke test against public test ad units, used by the iOS
// simulator pipeline (.github/workflows/ios.yml via tool/ios_sim_smoke.sh):
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/ad_smoke_test.dart -d <device> \
//     [--dart-define=NETWORKS=admob,unity] [--dart-define=LOAD_TIMEOUT_S=45] \
//     [--dart-define=SHOW=first|none|<network>]
//
// NETWORKS defaults to every adapter linked into the app. For each network
// it asserts that init succeeds and an interstitial loads within
// LOAD_TIMEOUT_S, with an `AdLoaded` event on `UnifiedAds.events`. Then one
// loaded interstitial is shown (SHOW, default: the first that loaded) and
// `AdShown` is asserted; only one is shown because an ad can't be closed
// without a tap. No uncaught platform exception may occur.
//
// Networks that can't serve test ads here are SKIPPED with the reason
// printed, not failed (tiers and credentials: integration_test/smoke_ids.dart).
// A `==== SMOKE SUMMARY ====` block is printed at the end for CI.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unified_ads/unified_ads.dart';

import 'smoke_ids.dart';
import 'support.dart';

const _networksDefine = String.fromEnvironment('NETWORKS');
const _loadTimeoutS = int.fromEnvironment('LOAD_TIMEOUT_S', defaultValue: 45);
const _show = String.fromEnvironment('SHOW', defaultValue: 'first');

/// Errors that escaped to the platform dispatcher (uncaught async errors).
final _uncaught = <String>[];
final _results = <AdNetwork, String>{};
final _seen = <AdEvent>[];
final _events = <String>[];
String _showResult = 'NOT RUN';
final _loaded = <AdNetwork, InterstitialAd>{};
final _started = DateTime.now();
late InitResult _init;
StreamSubscription<AdEvent>? _eventSub;

String _stamp() {
  final ms = DateTime.now().difference(_started).inMilliseconds;
  return '+${(ms / 1000).toStringAsFixed(1)}s';
}

void _log(String line) => debugPrint('[smoke ${_stamp()}] $line');

List<AdNetwork> _selected() {
  if (_networksDefine.trim().isEmpty) {
    return [
      for (final n in AdNetwork.values)
        if (AdapterRegistry.instance.adapterFor(n) != null) n,
    ];
  }
  return [
    for (final id in _networksDefine.split(','))
      if (id.trim().isNotEmpty)
        AdNetwork.tryParse(id.trim()) ??
            (throw ArgumentError.value(id, 'NETWORKS', 'unknown network')),
  ];
}

Future<void> _status(WidgetTester tester, String text) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'unified_ads smoke test\n$text',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Records a SKIP: printed, kept for the summary, and reported to the test
/// runner as skipped (not failed).
void _skip(AdNetwork network, String reason) {
  _results[network] = 'SKIP $reason';
  _log('SKIP ${network.id}: $reason');
  markTestSkipped('${network.id}: $reason');
}

Never _fail(AdNetwork network, String reason) {
  _results[network] = 'FAIL $reason';
  _log('FAIL ${network.id}: $reason');
  fail('${network.id}: $reason');
}

bool _hasEvent<T extends AdEvent>(AdNetwork network) =>
    _seen.any((e) => e is T && e.network == network);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  PlatformDispatcher.instance.onError = (error, stack) {
    _uncaught.add('$error');
    _log('UNCAUGHT $error\n$stack');
    return true;
  };

  final selected = _selected();
  final targets = smokeTargets();

  setUpAll(() async {
    UnifiedAds.logger = const AdsLogger.console(level: AdsLogLevel.debug);
    final runnable = [
      for (final n in selected)
        if (targets[n]?.config != null) n,
    ];
    _init = await UnifiedAds.init(
      AdConfig(
        testMode: true,
        preload: PreloadPolicy.none,
        loadTimeout: const Duration(seconds: _loadTimeoutS),
        initTimeout: const Duration(seconds: 60),
        waterfall: runnable,
        networks: {for (final n in runnable) n: targets[n]!.config!},
      ),
    );
    _log('init: $_init');
    _eventSub = UnifiedAds.events.listen((e) {
      _seen.add(e);
      _events.add('${_stamp()} ${e.network.id}/${e.format.id}:${e.kind}');
    });
  });

  tearDownAll(() async {
    await _eventSub?.cancel();
    for (final ad in _loaded.values) {
      await ad.dispose();
    }
    debugPrint('==== SMOKE SUMMARY ====');
    for (final n in selected) {
      debugPrint('  ${n.id}: ${_results[n] ?? 'NOT RUN'}');
    }
    debugPrint('  show: ${_results.isEmpty ? '-' : _showResult}');
    debugPrint('  uncaught: ${_uncaught.isEmpty ? 'none' : _uncaught}');
    debugPrint('  events:');
    for (final e in _events) {
      debugPrint('    $e');
    }
    debugPrint('==== END SMOKE SUMMARY ====');
  });

  for (final network in selected) {
    final target = targets[network];
    final skipReason = target == null
        ? 'no smoke target defined'
        : target.skipReason;

    testWidgets('${network.id}: init + interstitial load', (tester) async {
      if (skipReason != null) {
        _skip(network, skipReason);
        return;
      }
      await _status(tester, '${network.displayName}: loading interstitial');

      final initError = _init.skipped[network] ?? _init.failed[network];
      if (!_init.ready.contains(network)) {
        if (initError?.code == AdErrorCode.configConflict) {
          _skip(network, describeError(initError));
          return;
        }
        _fail(network, 'init: ${describeError(initError ?? _init.error)}');
      }

      final ad = InterstitialAd(forceNetwork: network);
      final load = await ad.load();
      await tester.pump();
      if (load case AdFailure(:final error)) {
        await ad.dispose();
        const tolerated = {
          AdErrorCode.noFill,
          AdErrorCode.timeout,
          AdErrorCode.networkError,
        };
        if (target!.tier == SmokeTier.bestEffort &&
            tolerated.contains(error.code)) {
          _skip(network, 'load: ${describeError(error)}');
          return;
        }
        _fail(network, 'load: ${describeError(error)}');
      }
      expect(ad.servedBy, network);
      await waitFor(tester, () => _hasEvent<AdLoaded>(network));
      if (!_hasEvent<AdLoaded>(network)) {
        _fail(network, 'no AdLoaded event on UnifiedAds.events');
      }
      _loaded[network] = ad;
      _results[network] = 'PASS (loaded)';
      _log('PASS ${network.id}: interstitial loaded');
    });
  }

  testWidgets('show one interstitial', (tester) async {
    if (_show == 'none') {
      _showResult = 'SKIP SHOW=none';
      markTestSkipped(_showResult);
      return;
    }
    final chosen = _show == 'first'
        ? selected.where(_loaded.containsKey).firstOrNull
        : AdNetwork.tryParse(_show);
    final ad = _loaded.remove(chosen);
    if (chosen == null || ad == null) {
      _showResult = 'SKIP no loaded interstitial to show';
      _log(_showResult);
      markTestSkipped(_showResult);
      return;
    }
    final network = chosen;
    await _status(tester, '${network.displayName}: showing interstitial');
    final show = await ad.show();
    if (show case AdFailure(:final error)) {
      _showResult = 'FAIL ${network.id}: ${describeError(error)}';
      fail(_showResult);
    }
    await waitFor(
      tester,
      () => _hasEvent<AdShown>(network),
      timeout: const Duration(seconds: 15),
    );
    if (!_hasEvent<AdShown>(network)) {
      _showResult = 'FAIL ${network.id}: no AdShown event within 15 s';
      fail(_showResult);
    }
    _showResult = 'PASS ${network.id}';
    _results[network] = 'PASS (loaded + shown)';
    _log('PASS ${network.id}: interstitial shown');
    // Leave the ad on screen for the CI screenshot loop.
    await Future<void>.delayed(const Duration(seconds: 12));
  });

  testWidgets('no uncaught platform exceptions', (tester) async {
    expect(_uncaught, isEmpty, reason: 'uncaught errors: $_uncaught');
  });
}
