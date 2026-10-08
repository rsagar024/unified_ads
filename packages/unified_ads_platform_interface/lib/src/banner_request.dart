import 'package:flutter/foundation.dart';

import 'banner_size.dart';

/// Everything an adapter needs to create a native banner view.
@immutable
class BannerRequest {
  /// Creates a request.
  const BannerRequest({
    required this.adId,
    required this.adUnitId,
    required this.size,
    required this.testMode,
  });

  /// Identifier the adapter must use for all events of this banner.
  final String adId;

  /// Ad-unit / placement ID (may be empty for networks that do not use one).
  final String adUnitId;

  /// Requested size; adaptive sizes have their width filled in.
  final BannerSize size;

  /// Whether test ads are requested.
  final bool testMode;
}
