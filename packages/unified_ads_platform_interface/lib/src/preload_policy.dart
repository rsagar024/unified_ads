import 'package:flutter/foundation.dart';

import 'ad_format.dart';

/// Controls automatic preloading of full-screen ads.
///
/// For every format in [formats], the next ad is loaded into the cache as soon
/// as the previous one is closed (or fails to show), so `load()` on the next ad
/// object completes immediately. With [onInit], the first ad of each format is
/// also preloaded right after initialization.
@immutable
class PreloadPolicy {
  /// Creates a policy.
  const PreloadPolicy({
    this.formats = const {AdFormat.interstitial, AdFormat.rewarded},
    this.onInit = false,
  });

  /// A policy that never preloads.
  static const none = PreloadPolicy(formats: {});

  /// Full-screen formats that are refilled automatically.
  final Set<AdFormat> formats;

  /// Whether to preload [formats] right after initialization.
  final bool onInit;

  /// Whether [format] is preloaded.
  bool isEnabledFor(AdFormat format) =>
      format.isFullScreen && formats.contains(format);

  @override
  bool operator ==(Object other) =>
      other is PreloadPolicy &&
      other.onInit == onInit &&
      setEquals(other.formats, formats);

  @override
  int get hashCode => Object.hash(onInit, Object.hashAllUnordered(formats));
}
