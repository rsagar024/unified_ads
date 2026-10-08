import 'ad_error.dart';
import 'ad_event.dart';
import 'ad_format.dart';
import 'ad_handle.dart';
import 'ad_network.dart';
import 'ad_result.dart';
import 'banner_request.dart';
import 'consent.dart';
import 'network_config.dart';
import 'test_mode_support.dart';

/// Contract every network adapter package implements by extending this class.
///
/// Adapters register themselves from their `dartPluginClass`:
///
/// ```dart
/// class AdmobAdapter extends AdNetworkAdapter {
///   static void registerWith() =>
///       AdapterRegistry.instance.register(AdmobAdapter());
///   // ...
/// }
/// ```
///
/// ## Error contract
/// Methods never throw. Every failure, including native exceptions, is
/// returned as an [AdFailure] carrying an [AdError] whose network is
/// [network]. A format outside [supportedFormats] returns
/// [AdErrorCode.unsupportedFormat] without calling native code.
///
/// ## Event contract
/// [events] is a broadcast stream. For one ad the order is: loaded, then
/// shown / impression, then clicked (any number), then earnedReward (at most
/// once), then closed. Adapters normalise SDK quirks to this order.
///
/// ## Threading
/// Native SDK and UI calls run on the platform main thread; native-to-Dart
/// callbacks are delivered on the platform main thread.
abstract class AdNetworkAdapter {
  /// Allows subclasses to have `const` constructors.
  const AdNetworkAdapter();

  /// The network this adapter serves.
  AdNetwork get network;

  /// Formats this adapter can load. Empty for documented stubs.
  Set<AdFormat> get supportedFormats;

  /// How far [initialize]'s `testMode` flag is honoured.
  TestModeSupport get testModeSupport;

  /// Whether loads need a per-format ad-unit / placement ID. Networks keyed
  /// only by an app ID (Start.io) return `false`.
  bool get requiresAdUnitId => true;

  /// Initializes the SDK. Idempotent; calling it again with the same config is
  /// a no-op.
  Future<AdResult<void>> initialize(
    NetworkConfig config, {
    required bool testMode,
  });

  /// Loads a full-screen ad of [format].
  Future<AdResult<AdHandle>> load(AdFormat format, String adUnitId);

  /// Shows a previously loaded ad. Completes when the ad is presented (or
  /// failed to present), not when it is closed.
  Future<AdResult<void>> show(AdHandle handle);

  /// Whether [handle] is loaded, unexpired and not yet shown.
  bool isReady(AdHandle handle);

  /// Releases a loaded ad that will not be shown.
  Future<void> destroy(AdHandle handle);

  /// Platform-view type registered by the adapter's native banner factory,
  /// `dev.arovyx.plugin.unifiedads/<network>/banner`.
  String get bannerViewType;

  /// Creation parameters passed to the native banner view for [request].
  Map<String, Object?> bannerCreationParams(BannerRequest request);

  /// Forwards privacy signals to the SDK. May be called before [initialize].
  Future<void> applyConsent(ConsentState state);

  /// Stream of events for every ad of this adapter. Must stay listenable
  /// after [dispose], because a re-initialized session subscribes again.
  Stream<AdEvent> get events;

  /// Releases all ads and native resources. Safe to call more than once;
  /// [initialize] may be called again afterwards (re-init, hot restart).
  Future<void> dispose();
}
