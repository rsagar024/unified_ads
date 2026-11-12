import 'package:flutter/foundation.dart';

import 'ad_network.dart';
import 'ad_network_adapter.dart';

/// Holds the adapters available to unified_ads.
///
/// Adapter packages register themselves at startup through Flutter's
/// generated plugin registrant. Apps and tests may also register adapters
/// explicitly.
///
/// Once [lock] is called (by the core package during init), no further
/// [register] or [unregister] calls are accepted. This prevents a
/// compromised or rogue dependency from hijacking an adapter network after
/// initialization — for example, registering a fake `AdNetwork.admob`
/// adapter to intercept ad requests, capture ad-unit IDs, suppress real
/// ads, or serve attacker creatives (see PI-01).
final class AdapterRegistry {
  AdapterRegistry._();

  /// The process-wide registry.
  static final AdapterRegistry instance = AdapterRegistry._();

  final Map<AdNetwork, AdNetworkAdapter> _adapters = {};
  bool _locked = false;

  /// Whether the registry has been locked. After locking, [register] and
  /// [unregister] throw a StateError.
  bool get isLocked => _locked;

  /// Registers [adapter], replacing any adapter already registered for the
  /// same network.
  ///
  /// Throws a StateError if the registry is locked. Call this before the
  /// core package initializes (adapters self-register via their plugin
  /// registrant).
  void register(AdNetworkAdapter adapter) {
    if (_locked) {
      throw StateError(
        'AdapterRegistry is locked; cannot register adapter for '
        '${adapter.network.id}. Register adapters before UnifiedAds.init.',
      );
    }
    _adapters[adapter.network] = adapter;
  }

  /// Removes the adapter for [network], if any.
  ///
  /// Throws a StateError if the registry is locked.
  void unregister(AdNetwork network) {
    if (_locked) {
      throw StateError(
        'AdapterRegistry is locked; cannot unregister adapter for '
        '$network.',
      );
    }
    _adapters.remove(network);
  }

  /// Locks the registry. After this call, [register] and [unregister]
  /// throw a StateError. Idempotent: calling [lock] on an already-locked
  /// registry is a no-op. Call this after all adapters have registered
  /// (typically at the start of the core package's init).
  void lock() {
    _locked = true;
  }

  /// The adapter registered for [network], or `null`.
  AdNetworkAdapter? adapterFor(AdNetwork network) => _adapters[network];

  /// Whether an adapter is registered for [network].
  bool isRegistered(AdNetwork network) => _adapters.containsKey(network);

  /// All registered adapters.
  Iterable<AdNetworkAdapter> get adapters =>
      List.unmodifiable(_adapters.values);

  /// Removes every adapter and resets the lock state. For tests only.
  @visibleForTesting
  void clear() {
    _adapters.clear();
    _locked = false;
  }
}
