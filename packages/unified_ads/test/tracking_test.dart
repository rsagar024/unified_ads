import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads/src/runtime.dart';
import 'package:unified_ads/src/tracking_channel.dart';
import 'package:unified_ads/unified_ads.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.arovyx.plugin.unifiedads/tracking');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await resetAll();
  });

  const ios = MethodChannelTracking(platform: TargetPlatform.iOS);

  test('maps native status names', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return 'authorized';
    });

    expect(await ios.request(), TrackingStatus.authorized);
    expect(await ios.status(), TrackingStatus.authorized);
    expect(calls, ['requestTracking', 'getTrackingStatus']);
  });

  test(
    'unknown values, missing plugin and errors become unavailable',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => 'banana');
      expect(await ios.status(), TrackingStatus.unavailable);

      messenger.setMockMethodCallHandler(channel, null);
      expect(await ios.status(), TrackingStatus.unavailable);

      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'ERR'),
      );
      expect(await ios.request(), TrackingStatus.unavailable);
    },
  );

  test('is not applicable on Android', () async {
    const android = MethodChannelTracking(platform: TargetPlatform.android);
    expect(await android.request(), TrackingStatus.notApplicable);
  });

  test('UnifiedAds never throws from tracking calls', () async {
    AdsRuntime.instance.tracking = _ThrowingTracking();

    expect(
      await UnifiedAds.requestTrackingAuthorization(),
      TrackingStatus.unavailable,
    );
    expect(
      await UnifiedAds.trackingAuthorizationStatus(),
      TrackingStatus.unavailable,
    );
  });
}

class _ThrowingTracking extends TrackingAuthorization {
  @override
  Future<TrackingStatus> request() => throw StateError('boom');

  @override
  Future<TrackingStatus> status() => throw StateError('boom');
}
