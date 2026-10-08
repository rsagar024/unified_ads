import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'config_schema.dart';

/// Loads an [AdConfig] from JSON (declarative configuration).
///
/// Schema (every key optional unless stated):
///
/// ```json
/// {
///   "testMode": true,
///   "waterfall": ["admob", "unity", "inmobi"],
///   "loadTimeoutMs": 10000,
///   "initTimeoutMs": 20000,
///   "cacheTtlSeconds": 3600,
///   "preload": { "formats": ["interstitial", "rewarded"], "onInit": false },
///   "frequencyCaps": { "interstitial": { "maxShows": 3, "perSeconds": 3600 } },
///   "networks": {
///     "admob": {
///       "enabled": true,
///       "appId": { "android": "ca-app-pub-…~…", "ios": "ca-app-pub-…~…" },
///       "bannerAdUnitId": "…",
///       "interstitialAdUnitId": "…",
///       "rewardedAdUnitId": "…",
///       "testMode": false,
///       "enabledFormats": ["banner", "interstitial"],
///       "testDeviceIds": [],
///       "extras": {}
///     }
///   }
/// }
/// ```
///
/// Any ID may be a string or an `{"android": …, "ios": …}` object. Unknown
/// keys are rejected with an [AdErrorCode.invalidConfig] error naming the
/// JSON path.
///
/// The same schema can live in the app's `pubspec.yaml` under a
/// `unified_ads:` key: `dart run unified_ads:generate_config` validates it
/// and writes `assets/ads_config.json` for [fromAsset].
abstract final class AdConfigLoader {
  /// Loads and parses the JSON asset at [path] (for example
  /// `assets/ads_config.json`, declared under `flutter: assets:`).
  static Future<AdResult<AdConfig>> fromAsset(
    String path, {
    AssetBundle? bundle,
    TargetPlatform? platform,
  }) async {
    final String source;
    try {
      source = await (bundle ?? rootBundle).loadString(path);
    } catch (e) {
      return AdFailure(
        AdError(
          code: AdErrorCode.invalidConfig,
          message: 'Could not read $path: $e',
        ),
      );
    }
    return fromJsonString(source, platform: platform);
  }

  /// Parses a JSON document.
  static AdResult<AdConfig> fromJsonString(
    String source, {
    TargetPlatform? platform,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      return AdFailure(
        AdError(
          code: AdErrorCode.invalidConfig,
          message: 'Invalid JSON: ${e.message}',
        ),
      );
    }
    if (decoded is! Map<String, Object?>) {
      return const AdFailure(
        AdError(
          code: AdErrorCode.invalidConfig,
          message: r'$: the root must be a JSON object',
        ),
      );
    }
    return fromJson(decoded, platform: platform);
  }

  /// Parses an already-decoded JSON object.
  static AdResult<AdConfig> fromJson(
    Map<String, Object?> json, {
    TargetPlatform? platform,
  }) {
    final schemaError = validateConfigJson(json);
    if (schemaError != null) {
      return AdFailure(
        AdError(code: AdErrorCode.invalidConfig, message: schemaError),
      );
    }
    try {
      return AdSuccess(_Parser(platform ?? defaultTargetPlatform).config(json));
    } on _ConfigException catch (e) {
      return AdFailure(
        AdError(
          code: AdErrorCode.invalidConfig,
          message: '${e.path}: ${e.message}',
        ),
      );
    }
  }

  /// Serializes [config] to the same schema. Platform-specific values are
  /// written as the strings resolved for the current platform.
  static Map<String, Object?> toJson(AdConfig config) {
    Map<String, Object?> network(NetworkConfig nc) => {
      if (!nc.enabled) 'enabled': false,
      if (nc.appId != null) 'appId': nc.appId,
      for (final format in AdFormat.values)
        if (nc.adUnitIdFor(format) != null)
          '${format.id}AdUnitId': nc.adUnitIdFor(format),
      if (nc.testMode != null) 'testMode': nc.testMode,
      if (nc.enabledFormats != null)
        'enabledFormats': [for (final f in nc.enabledFormats!) f.id],
      if (nc.testDeviceIds.isNotEmpty) 'testDeviceIds': nc.testDeviceIds,
      if (nc.extras.isNotEmpty) 'extras': nc.extras,
    };

    return {
      'testMode': config.testMode,
      if (config.waterfall.isNotEmpty)
        'waterfall': [for (final n in config.waterfall) n.id],
      'loadTimeoutMs': config.loadTimeout.inMilliseconds,
      'initTimeoutMs': config.initTimeout.inMilliseconds,
      'cacheTtlSeconds': config.cacheTtl.inSeconds,
      'preload': {
        'formats': [for (final f in config.preload.formats) f.id],
        'onInit': config.preload.onInit,
      },
      if (config.frequencyCaps.isNotEmpty)
        'frequencyCaps': {
          for (final MapEntry(key: format, value: cap)
              in config.frequencyCaps.entries)
            format.id: {
              'maxShows': cap.maxShows,
              'perSeconds': cap.per.inSeconds,
            },
        },
      'networks': {
        for (final MapEntry(key: n, value: nc) in config.networks.entries)
          n.id: network(nc),
      },
    };
  }
}

class _ConfigException implements Exception {
  _ConfigException(this.path, this.message);

  final String path;
  final String message;
}

class _Parser {
  _Parser(this.platform);

  final TargetPlatform platform;

  AdConfig config(Map<String, Object?> json) {
    const p = r'$';
    _checkKeys(json, configRootKeys, p);
    const defaults = AdConfig();
    return AdConfig(
      testMode: _opt<bool>(json, 'testMode', p) ?? defaults.testMode,
      waterfall: [
        for (final (i, id) in _stringList(json, 'waterfall', p).indexed)
          _network(id, '$p.waterfall[$i]'),
      ],
      networks: _networks(json, p),
      loadTimeout:
          _duration(json, 'loadTimeoutMs', p, ms: true) ?? defaults.loadTimeout,
      initTimeout:
          _duration(json, 'initTimeoutMs', p, ms: true) ?? defaults.initTimeout,
      cacheTtl:
          _duration(json, 'cacheTtlSeconds', p, ms: false) ?? defaults.cacheTtl,
      preload: _preload(json, p) ?? defaults.preload,
      frequencyCaps: _caps(json, p),
    );
  }

  Map<AdNetwork, NetworkConfig> _networks(Map<String, Object?> json, String p) {
    final raw = _opt<Map<String, Object?>>(json, 'networks', p);
    if (raw == null) return const {};
    return {
      for (final MapEntry(key: id, value: value) in raw.entries)
        _network(id, '$p.networks.$id'): _networkConfig(
          value,
          '$p.networks.$id',
        ),
    };
  }

  NetworkConfig _networkConfig(Object? value, String p) {
    if (value is! Map<String, Object?>) {
      throw _ConfigException(p, 'expected an object');
    }
    _checkKeys(value, configNetworkKeys, p);
    final formats = value.containsKey('enabledFormats')
        ? {
            for (final (i, id) in _stringList(
              value,
              'enabledFormats',
              p,
            ).indexed)
              _format(id, '$p.enabledFormats[$i]'),
          }
        : null;
    return NetworkConfig(
      enabled: _opt<bool>(value, 'enabled', p) ?? true,
      appId: _id(value, 'appId', p),
      bannerAdUnitId: _id(value, 'bannerAdUnitId', p),
      interstitialAdUnitId: _id(value, 'interstitialAdUnitId', p),
      rewardedAdUnitId: _id(value, 'rewardedAdUnitId', p),
      rewardedInterstitialAdUnitId: _id(
        value,
        'rewardedInterstitialAdUnitId',
        p,
      ),
      appOpenAdUnitId: _id(value, 'appOpenAdUnitId', p),
      testMode: _opt<bool>(value, 'testMode', p),
      enabledFormats: formats,
      testDeviceIds: _stringList(value, 'testDeviceIds', p),
      extras: _opt<Map<String, Object?>>(value, 'extras', p) ?? const {},
    );
  }

  PreloadPolicy? _preload(Map<String, Object?> json, String p) {
    final raw = _opt<Map<String, Object?>>(json, 'preload', p);
    if (raw == null) return null;
    final path = '$p.preload';
    _checkKeys(raw, configPreloadKeys, path);
    return PreloadPolicy(
      formats: raw.containsKey('formats')
          ? {
              for (final (i, id) in _stringList(raw, 'formats', path).indexed)
                _format(id, '$path.formats[$i]'),
            }
          : const PreloadPolicy().formats,
      onInit: _opt<bool>(raw, 'onInit', path) ?? false,
    );
  }

  Map<AdFormat, FrequencyCap> _caps(Map<String, Object?> json, String p) {
    final raw = _opt<Map<String, Object?>>(json, 'frequencyCaps', p);
    if (raw == null) return const {};
    final caps = <AdFormat, FrequencyCap>{};
    for (final MapEntry(key: id, value: value) in raw.entries) {
      final path = '$p.frequencyCaps.$id';
      if (value is! Map<String, Object?>) {
        throw _ConfigException(path, 'expected an object');
      }
      _checkKeys(value, configCapKeys, path);
      final maxShows = _opt<int>(value, 'maxShows', path);
      final per = _opt<int>(value, 'perSeconds', path);
      if (maxShows == null || per == null) {
        throw _ConfigException(path, 'maxShows and perSeconds are required');
      }
      caps[_format(id, path)] = FrequencyCap(
        maxShows: maxShows,
        per: Duration(seconds: per),
      );
    }
    return caps;
  }

  String? _id(Map<String, Object?> json, String key, String p) {
    final value = json[key];
    if (value == null || value is String) return value as String?;
    if (value is Map<String, Object?>) {
      _checkKeys(value, configPlatformKeys, '$p.$key');
      final android = _opt<String>(value, 'android', '$p.$key');
      final ios = _opt<String>(value, 'ios', '$p.$key');
      return PlatformValue.select(
        android: android,
        ios: ios,
        platform: platform,
      );
    }
    throw _ConfigException(
      '$p.$key',
      'expected a string or {"android": …, "ios": …}',
    );
  }

  Duration? _duration(
    Map<String, Object?> json,
    String key,
    String p, {
    required bool ms,
  }) {
    final value = _opt<int>(json, key, p);
    if (value == null) return null;
    return ms ? Duration(milliseconds: value) : Duration(seconds: value);
  }

  List<String> _stringList(Map<String, Object?> json, String key, String p) {
    final raw = _opt<List<Object?>>(json, key, p);
    if (raw == null) return const [];
    return [
      for (final (i, v) in raw.indexed)
        if (v is String)
          v
        else
          throw _ConfigException('$p.$key[$i]', 'expected a string'),
    ];
  }

  T? _opt<T extends Object>(Map<String, Object?> json, String key, String p) {
    final value = json[key];
    if (value == null) return null;
    if (value is! T) throw _ConfigException('$p.$key', 'expected $T');
    return value;
  }

  AdNetwork _network(String id, String path) =>
      AdNetwork.tryParse(id) ??
      (throw _ConfigException(
        path,
        'unknown network "$id" (expected one of '
        '${AdNetwork.values.map((n) => n.id).join(', ')})',
      ));

  AdFormat _format(String id, String path) =>
      AdFormat.tryParse(id) ??
      (throw _ConfigException(
        path,
        'unknown format "$id" (expected one of '
        '${AdFormat.values.map((f) => f.id).join(', ')})',
      ));

  void _checkKeys(Map<String, Object?> json, Set<String> allowed, String p) {
    for (final key in json.keys) {
      if (!allowed.contains(key)) {
        throw _ConfigException('$p.$key', 'unknown key');
      }
    }
  }
}
