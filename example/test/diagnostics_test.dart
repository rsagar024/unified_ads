import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_example/src/diagnostics.dart';
import 'package:unified_ads_example/src/event_log.dart';

void main() {
  test('reports init problems, config shape and events without IDs', () {
    final log = EventLog()
      ..add('init', 'initializing admob, unity')
      ..add(
        'load',
        'no fill',
        network: AdNetwork.unity,
        format: AdFormat.interstitial,
        isError: true,
      );
    const config = AdConfig(
      testMode: true,
      waterfall: [AdNetwork.admob, AdNetwork.unity],
      networks: {
        AdNetwork.admob: NetworkConfig(
          appId: 'ca-app-pub-secret~1',
          interstitialAdUnitId: 'ca-app-pub-secret/2',
        ),
        AdNetwork.unity: NetworkConfig(appId: '14850'),
      },
    );
    const result = InitResult(
      ready: {AdNetwork.admob},
      failed: {
        AdNetwork.unity: AdError(
          code: AdErrorCode.initializationFailed,
          message: 'boom',
          network: AdNetwork.unity,
          nativeCode: '3',
        ),
      },
    );

    final report = buildDiagnosticsReport(
      log,
      config: config,
      initResult: result,
      now: DateTime.utc(2026, 10, 12),
    );

    expect(report, contains('generated: 2026-10-12T00:00:00.000Z'));
    expect(report, contains('unity: initializationFailed (native 3): boom'));
    expect(report, contains('waterfall: admob, unity'));
    expect(report, contains('admob: enabled=true testMode=true appId=set'));
    expect(report, contains('interstitial=set rewarded=-'));
    expect(report, contains('ERROR load [unity/interstitial] no fill'));
    expect(report, contains('events (newest first, 2 of 2)'));
    // IDs are never copied.
    expect(report, isNot(contains('secret')));
    expect(report, isNot(contains('14850')));
  });

  test('limits the number of events', () {
    final log = EventLog();
    for (var i = 0; i < 5; i++) {
      log.add('step', 'event $i');
    }
    final report = buildDiagnosticsReport(log, maxEvents: 2);
    expect(report, contains('events (newest first, 2 of 5)'));
  });
}
