import 'ad_error.dart';
import 'ad_event.dart';
import 'ad_format.dart';
import 'ad_handle.dart';
import 'ad_network.dart';
import 'ad_network_adapter.dart';
import 'ad_result.dart';
import 'banner_request.dart';
import 'consent.dart';
import 'network_config.dart';
import 'test_mode_support.dart';

/// An adapter for a network that cannot serve ads through unified_ads.
///
/// Every operation fails with [AdErrorCode.unsupportedNetwork] and [reason].
/// Used by documented stubs: adapters for networks that cannot be integrated
/// directly.
class UnsupportedAdNetworkAdapter extends AdNetworkAdapter {
  /// Creates a stub adapter for [network].
  const UnsupportedAdNetworkAdapter({
    required this.network,
    required this.reason,
  });

  @override
  final AdNetwork network;

  /// Explanation included in every error.
  final String reason;

  AdError get _error => AdError(
    code: AdErrorCode.unsupportedNetwork,
    message: reason,
    network: network,
  );

  @override
  Set<AdFormat> get supportedFormats => const {};

  @override
  TestModeSupport get testModeSupport => TestModeSupport.none;

  @override
  Future<AdResult<void>> initialize(
    NetworkConfig config, {
    required bool testMode,
  }) async => AdFailure(_error);

  @override
  Future<AdResult<AdHandle>> load(AdFormat format, String adUnitId) async =>
      AdFailure(_error);

  @override
  Future<AdResult<void>> show(AdHandle handle) async => AdFailure(_error);

  @override
  bool isReady(AdHandle handle) => false;

  @override
  Future<void> destroy(AdHandle handle) async {}

  @override
  String get bannerViewType => '';

  @override
  Map<String, Object?> bannerCreationParams(BannerRequest request) => const {};

  @override
  Future<void> applyConsent(ConsentState state) async {}

  @override
  Stream<AdEvent> get events => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
