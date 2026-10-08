import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

/// One-slot-per-format cache of preloaded full-screen ads.
///
/// The cache only stores handles; destroying evicted handles is the caller's
/// job (it owns the adapters).
class AdCache {
  /// Creates a cache whose entries expire after [ttl], measured with [now].
  AdCache({required this.ttl, required this.now});

  /// Entry lifetime.
  final Duration ttl;

  /// Clock.
  final DateTime Function() now;

  final Map<AdFormat, ({AdHandle handle, DateTime cachedAt})> _slots = {};

  /// Stores [handle], returning the handle it replaced (if any).
  AdHandle? put(AdHandle handle) {
    final previous = _slots[handle.format]?.handle;
    _slots[handle.format] = (handle: handle, cachedAt: now());
    return previous;
  }

  /// Whether a non-expired entry exists for [format].
  bool has(AdFormat format) {
    final entry = _slots[format];
    return entry != null && !_isExpired(entry.cachedAt);
  }

  /// The cached handle for [format] without removing it, if not expired.
  AdHandle? peek(AdFormat format) =>
      has(format) ? _slots[format]!.handle : null;

  /// Removes and returns the entry for [format].
  ///
  /// [expired] receives an entry that was found but had expired, so the
  /// caller can destroy it; `null` is then returned.
  AdHandle? take(AdFormat format, {void Function(AdHandle handle)? expired}) {
    final entry = _slots.remove(format);
    if (entry == null) return null;
    if (_isExpired(entry.cachedAt)) {
      expired?.call(entry.handle);
      return null;
    }
    return entry.handle;
  }

  /// Removes every entry and returns the removed handles.
  List<AdHandle> clear() {
    final handles = [for (final e in _slots.values) e.handle];
    _slots.clear();
    return handles;
  }

  bool _isExpired(DateTime cachedAt) => !now().isBefore(cachedAt.add(ttl));
}
