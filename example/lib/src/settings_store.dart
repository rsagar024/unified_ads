import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_ads/unified_ads.dart';

import 'test_credentials.dart';

/// Persists the example's [AdConfig] in `shared_preferences`, using the same
/// JSON schema as `ads_config.json` ([AdConfigLoader]).
class SettingsStore {
  /// Creates a store.
  const SettingsStore();

  static const _key = 'unified_ads_example.config';

  /// The saved configuration, or [TestCredentials.defaults] when nothing (or
  /// nothing valid) is saved.
  Future<AdConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return TestCredentials.defaults();
    final result = AdConfigLoader.fromJsonString(saved);
    return result.valueOrNull ?? TestCredentials.defaults();
  }

  /// Saves [config].
  Future<void> save(AdConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(AdConfigLoader.toJson(config)));
  }

  /// Forgets the saved configuration and returns the defaults.
  Future<AdConfig> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    return TestCredentials.defaults();
  }
}
