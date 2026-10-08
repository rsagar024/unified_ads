import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

/// [TrackingAuthorization] backed by the core plugin's iOS ATT helper.
class MethodChannelTracking extends TrackingAuthorization {
  /// Creates the channel-backed implementation.
  const MethodChannelTracking({
    this.channel = const MethodChannel('dev.arovyx.plugin.unifiedads/tracking'),
    this.platform,
  });

  /// Channel to the native helper.
  final MethodChannel channel;

  /// Platform override for tests; defaults to [defaultTargetPlatform].
  final TargetPlatform? platform;

  @override
  Future<TrackingStatus> status() => _invoke('getTrackingStatus');

  @override
  Future<TrackingStatus> request() => _invoke('requestTracking');

  Future<TrackingStatus> _invoke(String method) async {
    if ((platform ?? defaultTargetPlatform) != TargetPlatform.iOS) {
      return TrackingStatus.notApplicable;
    }
    try {
      final name = await channel.invokeMethod<String>(method);
      return TrackingStatus.values.asNameMap()[name] ??
          TrackingStatus.unavailable;
    } on MissingPluginException {
      return TrackingStatus.unavailable;
    } on PlatformException catch (e) {
      AdsLogger.current.warning('tracking $method failed', error: e);
      return TrackingStatus.unavailable;
    }
  }
}
