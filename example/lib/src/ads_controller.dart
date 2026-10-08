import 'package:flutter/foundation.dart';
import 'package:unified_ads/unified_ads.dart';
import 'package:unified_ads_admob/unified_ads_admob.dart';

import 'event_log.dart';
import 'settings_store.dart';

/// Where a network stands after the last init.
enum NetworkState {
  /// Not initialized yet (or init is running).
  pending,

  /// Initialized and able to serve ads.
  ready,

  /// Init failed.
  failed,

  /// Skipped by config: disabled, invalid IDs, or a conflict.
  skipped,
}

/// A network's state plus the reason when it isn't ready.
typedef NetworkStatus = ({NetworkState state, AdError? error});

/// Owns the example's configuration and the ATT → consent → init flow.
class AdsController extends ChangeNotifier {
  /// Creates a controller.
  AdsController({required this.log, this.store = const SettingsStore()});

  /// The event console.
  final EventLog log;

  /// Where the configuration is saved.
  final SettingsStore store;

  AdConfig? _config;
  InitResult? _result;
  bool _busy = false;
  bool _privacyDone = false;
  int _generation = 0;

  /// The current configuration (null until [start]).
  AdConfig? get config => _config;

  /// The last init result.
  InitResult? get result => _result;

  /// Whether init is running.
  bool get busy => _busy;

  /// Bumped on every init so ad widgets recreate their ad objects.
  int get generation => _generation;

  /// The state of [network] after the last init.
  NetworkStatus statusOf(AdNetwork network) {
    final result = _result;
    final nc = _config?.networks[network];
    if (nc == null || !nc.enabled) {
      return (state: NetworkState.skipped, error: null);
    }
    if (result == null || _busy) {
      return (state: NetworkState.pending, error: null);
    }
    if (result.ready.contains(network)) {
      return (state: NetworkState.ready, error: null);
    }
    if (result.failed[network] case final e?) {
      return (state: NetworkState.failed, error: e);
    }
    return (state: NetworkState.skipped, error: result.skipped[network]);
  }

  /// Loads the saved configuration and initializes.
  Future<void> start() async {
    _config = await store.load();
    notifyListeners();
    await _initialize();
  }

  /// Saves [config] and re-initializes with it.
  Future<void> apply(AdConfig config) async {
    await store.save(config);
    _config = config;
    log.add('settings', 'saved; re-initializing');
    await _initialize();
  }

  /// Restores the public test credentials and re-initializes.
  Future<void> resetToTestIds() async {
    _config = await store.reset();
    log.add('settings', 'reset to the public test IDs');
    await _initialize();
  }

  /// Re-initializes with the current configuration.
  Future<void> reinitialize() => _initialize();

  Future<void> _initialize() async {
    final config = _config;
    if (config == null || _busy) return;
    _busy = true;
    _generation++;
    notifyListeners();
    try {
      if (!_privacyDone) {
        _privacyDone = true;
        await _gatherPrivacy(config);
      }
      log.add('init', 'initializing ${_enabled(config).join(', ')}');
      final result = await UnifiedAds.init(config);
      _result = result;
      log.add('init', result.toString(), isError: !result.isSuccess);
      for (final MapEntry(key: network, value: error) in {
        ...result.failed,
        ...result.skipped,
      }.entries) {
        if (config.networks[network]?.enabled ?? false) {
          log.add(
            'init',
            '${error.code.name}: ${error.message}',
            network: network,
            isError: true,
          );
        }
      }
    } finally {
      _busy = false;
      _generation++;
      notifyListeners();
    }
  }

  Future<void> _gatherPrivacy(AdConfig config) async {
    final tracking = await UnifiedAds.requestTrackingAuthorization();
    log.add('privacy', 'ATT: ${tracking.name}');
    if (config.networks[AdNetwork.admob]?.enabled ?? false) {
      final consent = await UnifiedAds.gatherConsent(
        const AdmobConsentProvider(),
      );
      log.add('privacy', 'consent: $consent');
    }
  }

  static List<String> _enabled(AdConfig config) => [
    for (final MapEntry(key: n, value: nc) in config.networks.entries)
      if (nc.enabled) n.id,
  ];
}
