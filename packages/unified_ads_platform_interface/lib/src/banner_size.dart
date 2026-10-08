import 'package:flutter/foundation.dart';

/// The kind of banner size requested.
enum BannerSizeType {
  /// 320×50.
  standard,

  /// 320×100.
  largeBanner,

  /// 300×250 (MREC).
  mediumRectangle,

  /// 728×90 (tablets).
  leaderboard,

  /// Full-width banner sized by the network for anchoring at the top or
  /// bottom of the screen.
  adaptiveAnchored,

  /// Full-width banner placed inside scrolling content, optionally capped by a
  /// maximum height.
  adaptiveInline,
}

/// Requested banner size.
///
/// Fixed sizes have a known [width] and [height]. Adaptive sizes take the
/// available width (filled in by the banner widget) and the network resolves
/// the height. Networks without adaptive support fall back to [standard].
@immutable
class BannerSize {
  const BannerSize._(this.type, {this.width, this.height, this.maxHeight});

  /// A full-width banner for anchoring at the top or bottom of the screen.
  /// [width] defaults to the available width.
  const BannerSize.adaptiveAnchored({double? width})
    : this._(BannerSizeType.adaptiveAnchored, width: width);

  /// A full-width banner inside scrolling content. [width] defaults to the
  /// available width; [maxHeight] optionally caps the resolved height.
  const BannerSize.adaptiveInline({double? width, double? maxHeight})
    : this._(BannerSizeType.adaptiveInline, width: width, maxHeight: maxHeight);

  /// 320×50 standard banner.
  static const standard = BannerSize._(
    BannerSizeType.standard,
    width: 320,
    height: 50,
  );

  /// 320×100 large banner.
  static const largeBanner = BannerSize._(
    BannerSizeType.largeBanner,
    width: 320,
    height: 100,
  );

  /// 300×250 medium rectangle (MREC).
  static const mediumRectangle = BannerSize._(
    BannerSizeType.mediumRectangle,
    width: 300,
    height: 250,
  );

  /// 728×90 leaderboard (tablets).
  static const leaderboard = BannerSize._(
    BannerSizeType.leaderboard,
    width: 728,
    height: 90,
  );

  /// The kind of size.
  final BannerSizeType type;

  /// Width in logical pixels, or `null` for "available width".
  final double? width;

  /// Height in logical pixels, or `null` when the network decides.
  final double? height;

  /// Maximum height for [BannerSizeType.adaptiveInline], if any.
  final double? maxHeight;

  /// Whether the network resolves the final size.
  bool get isAdaptive =>
      type == BannerSizeType.adaptiveAnchored ||
      type == BannerSizeType.adaptiveInline;

  /// Height to reserve before the network reports the real size.
  double get fallbackHeight => height ?? 50;

  /// Returns this size with [width] filled in, if it is adaptive and has no
  /// explicit width yet. Fixed sizes are returned unchanged.
  BannerSize withWidth(double width) {
    if (!isAdaptive || this.width != null) return this;
    return BannerSize._(type, width: width, maxHeight: maxHeight);
  }

  /// Serializable form, for platform-view creation parameters.
  Map<String, Object?> toMap() => {
    'type': type.name,
    'width': width,
    'height': height,
    'maxHeight': maxHeight,
  };

  @override
  bool operator ==(Object other) =>
      other is BannerSize &&
      other.type == type &&
      other.width == width &&
      other.height == height &&
      other.maxHeight == maxHeight;

  @override
  int get hashCode => Object.hash(type, width, height, maxHeight);

  @override
  String toString() =>
      'BannerSize(${type.name}, ${width ?? '?'}x${height ?? '?'})';
}
