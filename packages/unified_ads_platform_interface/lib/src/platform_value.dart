import 'package:flutter/foundation.dart';

/// Helper for values that differ between Android and iOS, such as Unity Game
/// IDs or ad-unit IDs.
///
/// ```dart
/// NetworkConfig(
///   appId: PlatformValue.select(android: '1234567', ios: '7654321'),
/// )
/// ```
abstract final class PlatformValue {
  /// Returns [ios] on iOS and [android] on every other platform.
  ///
  /// [platform] defaults to [defaultTargetPlatform]; pass it explicitly in
  /// tests.
  static T select<T>({
    required T android,
    required T ios,
    TargetPlatform? platform,
  }) {
    return (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
        ? ios
        : android;
  }
}
