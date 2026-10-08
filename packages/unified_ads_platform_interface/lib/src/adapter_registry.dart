import 'package:flutter/foundation.dart';

import 'ad_network.dart';
import 'ad_network_adapter.dart';

/// Holds the adapters available to unified_ads.
///
/// Adapter packages register themselves at startup through Flutter's
/// generated plugin registrant. Apps and tests may also register adapters
/// explicitly.
final class AdapterRegistry {
  AdapterRegistry._();

  /// The process-wide registry.
  static final AdapterRegistry instance = AdapterRegistry._();

  final Map<AdNetwork, AdNetworkAdapter> _adapters = {};

  /// Registers [adapter], replacing any adapter already registered for the
  /// same network.
  void register(AdNetworkAdapter adapter) {
    _adapters[adapter.network] = adapter;
  }

  /// Removes the adapter for [network], if any.
  void unregister(AdNetwork network) {
    _adapters.remove(network);
  }

  /// The adapter registered for [network], or `null`.
  AdNetworkAdapter? adapterFor(AdNetwork network) => _adapters[network];

  /// Whether an adapter is registered for [network].
  bool isRegistered(AdNetwork network) => _adapters.containsKey(network);

  /// All registered adapters.
  Iterable<AdNetworkAdapter> get adapters =>
      List.unmodifiable(_adapters.values);

  /// Removes every adapter. For tests only.
  @visibleForTesting
  void clear() => _adapters.clear();
}
