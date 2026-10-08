import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

/// Runs an adapter call that returns an [AdResult], converting anything it
/// throws into an [AdFailure] so a faulty adapter can never crash the app.
Future<AdResult<T>> guardCall<T>(
  AdNetwork network,
  String operation,
  Future<AdResult<T>> Function() body,
) async {
  try {
    final result = await body();
    if (result case AdFailure<T>(:final error) when error.network == null) {
      return AdFailure(error.copyWith(network: network));
    }
    return result;
  } catch (e, st) {
    AdsLogger.current.error(
      '$operation threw',
      network: network,
      error: e,
      stackTrace: st,
    );
    return AdFailure(AdError.fromException(e, network: network));
  }
}

/// Runs an adapter call without a result, logging and swallowing anything it
/// throws.
Future<void> guardVoid(
  AdNetwork network,
  String operation,
  Future<void> Function() body,
) async {
  try {
    await body();
  } catch (e, st) {
    AdsLogger.current.error(
      '$operation threw',
      network: network,
      error: e,
      stackTrace: st,
    );
  }
}

/// Synchronous variant of [guardCall] for cheap adapter queries.
T guardSync<T>(
  AdNetwork network,
  String operation,
  T fallback,
  T Function() body,
) {
  try {
    return body();
  } catch (e, st) {
    AdsLogger.current.error(
      '$operation threw',
      network: network,
      error: e,
      stackTrace: st,
    );
    return fallback;
  }
}

/// Invokes an app-supplied callback, logging (never propagating) exceptions so
/// a throwing listener cannot break the ad pipeline.
void safeCallback(String name, void Function() callback) {
  try {
    callback();
  } catch (e, st) {
    AdsLogger.current.error(
      'App callback $name threw',
      error: e,
      stackTrace: st,
    );
  }
}
