import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_ads/unified_ads.dart';

import 'test_credentials.dart';

/// Constant-time string comparison to avoid timing side-channels when
/// verifying HMACs. Returns true only when [a] and [b] are identical.
bool _secureStringEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Persists the example's [AdConfig] in `shared_preferences` with HMAC-SHA256
/// integrity protection.
///
/// The config JSON is authenticated with an HMAC key generated on first run
/// and stored in `shared_preferences`. On load, the HMAC is verified before
/// the config is accepted; any tampering causes a fallback to defaults so an
/// attacker who can modify `shared_preferences` cannot inject ad-unit IDs,
/// disable frequency caps, or point loads at attacker-controlled placements.
class SettingsStore {
  /// Creates a store.
  const SettingsStore();

  static const _key = 'unified_ads_example.config';
  static const _hmacKey = 'unified_ads_example.hmac_key';
  static const _adFreeKey = 'unified_ads_example.adFree';
  static const _blockRewardedKey = 'unified_ads_example.blockRewarded';

  /// Separate HMAC for the ad-free switch (security-relevant flag).
  static const _adFreeHmacKey = 'unified_ads_example.adFree_hmac';

  /// The saved configuration, or [TestCredentials.defaults] when nothing (or
  /// nothing valid/authentic) is saved.
  Future<AdConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return TestCredentials.defaults();

    final parts = saved.split('|');
    if (parts.length != 2) {
      // Malformed storage: do not trust.
      return TestCredentials.defaults();
    }

    final configJson = parts[0];
    final providedHmac = parts[1];

    final hmacKey = await _getHmacKey(prefs);
    if (hmacKey.isEmpty) {
      // No key yet: nothing authentic can be stored.
      return TestCredentials.defaults();
    }

    final expectedHmac = _computeHmac(hmacKey, configJson);

    if (!_secureStringEquals(providedHmac, expectedHmac)) {
      // HMAC mismatch: config was tampered with. Do not trust.
      return TestCredentials.defaults();
    }

    final result = AdConfigLoader.fromJsonString(configJson);
    return result.valueOrNull ?? TestCredentials.defaults();
  }

  /// Saves [config] with HMAC-SHA256 integrity protection.
  Future<void> save(AdConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = jsonEncode(AdConfigLoader.toJson(config));
    final hmacKey = await _getOrCreateHmacKey(prefs);
    final hmac = _computeHmac(hmacKey, configJson);
    await prefs.setString(_key, '$configJson|$hmac');
  }

  /// The saved ad-free ("Pro user") switch with HMAC integrity.
  Future<({bool adFree, bool blockRewarded})> loadAdFree() async {
    final prefs = await SharedPreferences.getInstance();
    final adFreeRaw = prefs.getString(_adFreeKey);
    final blockRewardedRaw = prefs.getString(_blockRewardedKey);
    final adFreeHmacRaw = prefs.getString(_adFreeHmacKey);

    if (adFreeRaw == null ||
        blockRewardedRaw == null ||
        adFreeHmacRaw == null) {
      return (adFree: false, blockRewarded: false);
    }

    final hmacKey = await _getHmacKey(prefs);
    if (hmacKey.isEmpty) {
      return (adFree: false, blockRewarded: false);
    }

    final message = '$adFreeRaw|$blockRewardedRaw';
    final expectedHmac = _computeHmac(hmacKey, message);

    if (!_secureStringEquals(adFreeHmacRaw, expectedHmac)) {
      return (adFree: false, blockRewarded: false);
    }

    return (
      adFree: adFreeRaw == 'true',
      blockRewarded: blockRewardedRaw == 'true',
    );
  }

  /// Saves the ad-free switch with HMAC integrity.
  Future<void> saveAdFree({
    required bool adFree,
    required bool blockRewarded,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hmacKey = await _getOrCreateHmacKey(prefs);
    final message =
        '${adFree ? 'true' : 'false'}|${blockRewarded ? 'true' : 'false'}';
    final hmac = _computeHmac(hmacKey, message);
    await prefs.setString(_adFreeKey, adFree ? 'true' : 'false');
    await prefs.setString(
      _blockRewardedKey,
      blockRewarded ? 'true' : 'false',
    );
    await prefs.setString(_adFreeHmacKey, hmac);
  }

  /// Forgets the saved configuration and returns the defaults.
  Future<AdConfig> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_hmacKey);
    await prefs.remove(_adFreeKey);
    await prefs.remove(_blockRewardedKey);
    await prefs.remove(_adFreeHmacKey);
    return TestCredentials.defaults();
  }

  /// Returns the stored HMAC key, generating one on first use.
  Future<String> _getOrCreateHmacKey(SharedPreferences prefs) async {
    final existing = prefs.getString(_hmacKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final key = _generateRandomKey(32);
    await prefs.setString(_hmacKey, key);
    return key;
  }

  Future<String> _getHmacKey(SharedPreferences prefs) async {
    final existing = prefs.getString(_hmacKey);
    if (existing == null || existing.isEmpty) {
      // No key yet: nothing authentic can be stored.
      return '';
    }
    return existing;
  }

  /// Generates a random key of [length] bytes as a base64 string.
  String _generateRandomKey(int length) {
    final secure = Random.secure();
    final values = List<int>.generate(length, (_) => secure.nextInt(256));
    return base64.encode(values);
  }

  /// Computes HMAC-SHA256 of [message] using [key].
  String _computeHmac(String keyBase64, String message) {
    final key = base64.decode(keyBase64);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(message));
    return base64.encode(digest.bytes);
  }
}
