import 'package:flutter/foundation.dart';

import 'ad_format.dart';
import 'ad_network.dart';

/// Opaque reference to a full-screen ad loaded by an adapter.
///
/// The [id] is assigned by the adapter and is unique within that adapter.
/// Events for the ad carry the same id.
@immutable
class AdHandle {
  /// Creates a handle.
  const AdHandle({
    required this.id,
    required this.network,
    required this.format,
    required this.adUnitId,
    required this.loadedAt,
  });

  /// Adapter-assigned identifier.
  final String id;

  /// The network that loaded the ad.
  final AdNetwork network;

  /// The ad's format.
  final AdFormat format;

  /// The ad-unit / placement ID used to load the ad.
  final String adUnitId;

  /// When the ad finished loading.
  final DateTime loadedAt;

  @override
  bool operator ==(Object other) =>
      other is AdHandle && other.id == id && other.network == network;

  @override
  int get hashCode => Object.hash(id, network);

  @override
  String toString() => 'AdHandle(${network.id}/${format.id}#$id)';
}
