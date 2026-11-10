// Pure Dart (no Flutter imports): shared by AdConfigLoader and the
// `generate_config` CLI, which runs on the plain Dart VM.

/// Network ids accepted in a declarative config (`AdNetwork.id`).
const configNetworkIds = [
  'admob',
  'unity',
  'applovin',
  'ironsource',
  'facebook',
  'startapp',
  'inmobi',
];

/// Format ids accepted in a declarative config (`AdFormat.id`).
const configFormatIds = [
  'banner',
  'interstitial',
  'rewarded',
  'rewardedInterstitial',
  'appOpen',
];

/// Keys allowed at the root of a declarative config.
const configRootKeys = {
  'testMode',
  'waterfall',
  'networks',
  'loadTimeoutMs',
  'initTimeoutMs',
  'showTimeoutMs',
  'cacheTtlSeconds',
  'preload',
  'frequencyCaps',
  'pacing',
};

/// Keys allowed inside `networks.<id>`.
const configNetworkKeys = {
  'enabled',
  'appId',
  'bannerAdUnitId',
  'interstitialAdUnitId',
  'rewardedAdUnitId',
  'rewardedInterstitialAdUnitId',
  'appOpenAdUnitId',
  'testMode',
  'enabledFormats',
  'testDeviceIds',
  'extras',
};

/// Keys allowed inside `preload`.
const configPreloadKeys = {'formats', 'onInit'};

/// Keys allowed inside `frequencyCaps.<format>`.
const configCapKeys = {'maxShows', 'perSeconds'};

/// Keys allowed inside `pacing.<format>`.
const configPacingKeys = {
  'minIntervalSeconds',
  'showEveryActions',
  'initialDelaySeconds',
};

/// Keys allowed inside a per-platform ID object.
const configPlatformKeys = {'android', 'ios'};

/// Network-config keys whose value is an ID (a string or a per-platform
/// object).
const configIdKeys = {
  'appId',
  'bannerAdUnitId',
  'interstitialAdUnitId',
  'rewardedAdUnitId',
  'rewardedInterstitialAdUnitId',
  'appOpenAdUnitId',
};

/// Maximum number of entries allowed in `extras`.
const configExtrasMaxEntries = 16;

/// Maximum length (in characters) for a string value in `extras`.
const configExtrasMaxValueLength = 256;

/// Maximum JSON nesting depth allowed in a declarative config.
const configMaxJsonDepth = 8;

/// Maximum total number of keys allowed in a declarative config.
const configMaxJsonKeys = 200;

/// Maximum length (in characters) for any string value in a declarative config.
const configMaxJsonStringLength = 1024;

/// Validates the structure of a decoded JSON value for depth and size limits.
///
/// Throws [SchemaError] if the JSON is too deeply nested, has too many keys,
/// or contains strings that are too long.
void validateJsonStructure(Object? json,
    {int depth = 0, List<int>? keyCount}) {
  keyCount ??= [0];

  if (depth > configMaxJsonDepth) {
    throw SchemaError(
      r'$',
      'JSON nesting depth exceeds $configMaxJsonDepth levels',
    );
  }

  if (json is Map<String, Object?>) {
    keyCount[0] += json.length;
    if (keyCount[0] > configMaxJsonKeys) {
      throw SchemaError(
        '\$',
        'JSON object has too many keys (max $configMaxJsonKeys total)',
      );
    }
    for (final MapEntry(key: key, value: value) in json.entries) {
      if (key.length > configMaxJsonStringLength) {
        final displayKey = '${key.substring(0, 32)}...';
        throw SchemaError(
          r'$',
          'key "$displayKey" exceeds $configMaxJsonStringLength characters',
        );
      }
      validateJsonStructure(value, depth: depth + 1, keyCount: keyCount);
    }
  } else if (json is List<Object?>) {
    keyCount[0] += json.length;
    if (keyCount[0] > configMaxJsonKeys) {
      throw SchemaError(
        '\$',
        'JSON array has too many entries (max $configMaxJsonKeys total)',
      );
    }
    for (final item in json) {
      validateJsonStructure(item, depth: depth + 1, keyCount: keyCount);
    }
  } else if (json is String) {
    if (json.length > configMaxJsonStringLength) {
      throw SchemaError(
        '\$',
        'string value exceeds $configMaxJsonStringLength characters',
      );
    }
  }
}

/// Validates that [extras] contains only JSON-safe primitive values.
///
/// Throws [SchemaError] if [extras] contains disallowed types, too many
/// entries, or values that are too large.
void validateExtras(Map<String, Object?> extras, String path) {
  if (extras.length > configExtrasMaxEntries) {
    throw SchemaError(
      path,
      'extras has ${extras.length} entries (max $configExtrasMaxEntries)',
    );
  }
  for (final MapEntry(key: key, value: value) in extras.entries) {
    if (key.isEmpty) {
      throw SchemaError(
        '$path.$key',
        'extras keys must be non-empty strings',
      );
    }
    _validateExtrasValue(value, '$path.$key');
  }
}

void _validateExtrasValue(Object? value, String path) {
  if (value == null) {
    throw SchemaError(path, 'extras value must not be null');
  }
  if (value is String) {
    if (value.length > configExtrasMaxValueLength) {
      throw SchemaError(
        path,
        'extras string value exceeds $configExtrasMaxValueLength characters',
      );
    }
    return;
  }
  if (value is int) return;
  if (value is double) return;
  if (value is bool) return;
  if (value is List<Object?>) {
    if (value.length > configExtrasMaxEntries) {
      throw SchemaError(
        path,
        'extras list has ${value.length} entries (max $configExtrasMaxEntries)',
      );
    }
    for (final (i, item) in value.indexed) {
      if (item is! String &&
          item is! int &&
          item is! double &&
          item is! bool &&
          item != null) {
        throw SchemaError(
          '$path[$i]',
          'extras list items must be String, int, double, bool, or null',
        );
      }
      if (item is String && item.length > configExtrasMaxValueLength) {
        throw SchemaError(
          '$path[$i]',
          'extras list string exceeds $configExtrasMaxValueLength characters',
        );
      }
    }
    return;
  }
  if (value is Map<String, Object?>) {
    if (value.length > configExtrasMaxEntries) {
      throw SchemaError(
        path,
        'extras map has ${value.length} entries (max $configExtrasMaxEntries)',
      );
    }
    for (final MapEntry(key: k, value: v) in value.entries) {
      if (k.isEmpty) {
        throw SchemaError(
          '$path.$k',
          'extras map keys must be non-empty strings',
        );
      }
      _validateExtrasValue(v, '$path.$k');
    }
    return;
  }
  throw SchemaError(
    path,
    'extras value must be String, int, double, bool, List, or Map<String, Object?>',
  );
}

/// Checks the structure of a declarative config.
///
/// Returns `null` when [json] is valid, otherwise the first error as
/// `<json path>: <message>` (for example `$.networks.admob.bogus: unknown
/// key`).
String? validateConfigJson(Map<String, Object?> json) {
  try {
    _validateRoot(json);
    return null;
  } on SchemaError catch (e) {
    return '${e.path}: ${e.message}';
  }
}

/// Error thrown when a declarative config violates the schema or size limits.
class SchemaError implements Exception {
  /// Schema validation error with a JSON [path] and human-readable [message].
  ///
  /// Thrown by [validateConfigJson] and [validateJsonStructure] when a
  /// declarative config violates the schema or size limits.
  SchemaError(this.path, this.message);

  /// The JSON path where the error occurred.
  final String path;

  /// The human-readable error message.
  final String message;
}

void _validateRoot(Map<String, Object?> json) {
  const p = r'$';
  _checkKeys(json, configRootKeys, p);
  _opt<bool>(json, 'testMode', p);
  for (final (i, id) in _stringList(json, 'waterfall', p).indexed) {
    _network(id, '$p.waterfall[$i]');
  }
  final networks = _opt<Map<String, Object?>>(json, 'networks', p);
  if (networks != null) {
    for (final MapEntry(key: id, value: value) in networks.entries) {
      final path = '$p.networks.$id';
      _network(id, path);
      _validateNetwork(value, path);
    }
  }
  _opt<int>(json, 'loadTimeoutMs', p);
  _opt<int>(json, 'initTimeoutMs', p);
  _opt<int>(json, 'showTimeoutMs', p);
  _opt<int>(json, 'cacheTtlSeconds', p);
  final preload = _opt<Map<String, Object?>>(json, 'preload', p);
  if (preload != null) {
    final path = '$p.preload';
    _checkKeys(preload, configPreloadKeys, path);
    for (final (i, id) in _stringList(preload, 'formats', path).indexed) {
      _format(id, '$path.formats[$i]');
    }
    _opt<bool>(preload, 'onInit', path);
  }
  final caps = _opt<Map<String, Object?>>(json, 'frequencyCaps', p);
  if (caps != null) {
    for (final MapEntry(key: id, value: value) in caps.entries) {
      final path = '$p.frequencyCaps.$id';
      if (value is! Map<String, Object?>) {
        throw SchemaError(path, 'expected an object');
      }
      _checkKeys(value, configCapKeys, path);
      final maxShows = _opt<int>(value, 'maxShows', path);
      final per = _opt<int>(value, 'perSeconds', path);
      if (maxShows == null || per == null) {
        throw SchemaError(path, 'maxShows and perSeconds are required');
      }
      _format(id, path);
    }
  }
  final pacing = _opt<Map<String, Object?>>(json, 'pacing', p);
  if (pacing != null) {
    for (final MapEntry(key: id, value: value) in pacing.entries) {
      final path = '$p.pacing.$id';
      if (value is! Map<String, Object?>) {
        throw SchemaError(path, 'expected an object');
      }
      _checkKeys(value, configPacingKeys, path);
      for (final key in configPacingKeys) {
        _opt<int>(value, key, path);
      }
      _format(id, path);
    }
  }
}

void _validateNetwork(Object? value, String p) {
  if (value is! Map<String, Object?>) {
    throw SchemaError(p, 'expected an object');
  }
  _checkKeys(value, configNetworkKeys, p);
  for (final (i, id) in _stringList(value, 'enabledFormats', p).indexed) {
    _format(id, '$p.enabledFormats[$i]');
  }
  _opt<bool>(value, 'enabled', p);
  for (final key in configIdKeys) {
    _id(value, key, p);
  }
  _opt<bool>(value, 'testMode', p);
  _stringList(value, 'testDeviceIds', p);
  final extras = _opt<Map<String, Object?>>(value, 'extras', p);
  if (extras != null) {
    validateExtras(extras, p);
  }
}

void _id(Map<String, Object?> json, String key, String p) {
  final value = json[key];
  if (value == null || value is String) return;
  if (value is Map<String, Object?>) {
    _checkKeys(value, configPlatformKeys, '$p.$key');
    _opt<String>(value, 'android', '$p.$key');
    _opt<String>(value, 'ios', '$p.$key');
    return;
  }
  throw SchemaError(
    '$p.$key',
    'expected a string or {"android": …, "ios": …}',
  );
}

List<String> _stringList(Map<String, Object?> json, String key, String p) {
  final raw = _opt<List<Object?>>(json, key, p);
  if (raw == null) return const [];
  return [
    for (final (i, v) in raw.indexed)
      if (v is String)
        v
      else
        throw SchemaError('$p.$key[$i]', 'expected a string'),
  ];
}

T? _opt<T extends Object>(Map<String, Object?> json, String key, String p) {
  final value = json[key];
  if (value == null) return null;
  if (value is! T) throw SchemaError('$p.$key', 'expected $T');
  return value;
}

void _network(String id, String path) {
  if (!configNetworkIds.contains(id)) {
    throw SchemaError(
      path,
      'unknown network "$id" (expected one of ${configNetworkIds.join(', ')})',
    );
  }
}

void _format(String id, String path) {
  if (!configFormatIds.contains(id)) {
    throw SchemaError(
      path,
      'unknown format "$id" (expected one of ${configFormatIds.join(', ')})',
    );
  }
}

void _checkKeys(Map<String, Object?> json, Set<String> allowed, String p) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) throw SchemaError('$p.$key', 'unknown key');
  }
}
