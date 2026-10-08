import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'messages.g.dart';

/// Debug geography for testing the UMP consent flow.
enum UmpDebugGeography {
  /// Behave as if the device were in the EEA (GDPR form).
  eea,

  /// Behave as if the device were in a regulated US state.
  regulatedUsState,

  /// Behave as if the device were outside regulated regions.
  other,
}

/// [ConsentProvider] backed by Google's User Messaging Platform (UMP).
///
/// ```dart
/// final consent = await UnifiedAds.gatherConsent(const AdmobConsentProvider());
/// ```
///
/// UMP writes the IAB TCF / GPP strings to device storage, where AdMob,
/// AppLovin MAX, LevelPlay and InMobi read them automatically. The returned
/// [ConsentState] is derived from those strings, so other adapters receive the
/// same signals through `applyConsent`.
///
/// The consent form must be configured in the AdMob console (Privacy &
/// messaging). [debugGeography] and [testDeviceHashedIds] are for testing
/// only; the hashed ID is printed by UMP in the device log.
class AdmobConsentProvider extends ConsentProvider {
  /// Creates the provider. `hostApi` is for tests.
  const AdmobConsentProvider({
    this.debugGeography,
    this.testDeviceHashedIds = const [],
    this._hostApi,
  });

  /// Forces a debug geography (testing only).
  final UmpDebugGeography? debugGeography;

  /// Devices on which [debugGeography] applies (testing only).
  final List<String> testDeviceHashedIds;

  final AdmobHostApi? _hostApi;

  AdmobHostApi get _host => _hostApi ?? AdmobHostApi();

  /// Requests a consent-info update and shows the consent form if UMP
  /// requires it. With [forceForm], shows the privacy-options form instead
  /// when the user can change their choices.
  @override
  Future<ConsentState> gather({bool forceForm = false}) async {
    try {
      final info = await _host.gatherConsent(
        GatherRequest(
          forceForm: forceForm,
          debugGeography: switch (debugGeography) {
            UmpDebugGeography.eea => DebugGeographyMessage.eea,
            UmpDebugGeography.regulatedUsState =>
              DebugGeographyMessage.regulatedUsState,
            UmpDebugGeography.other => DebugGeographyMessage.other,
            null => null,
          },
          testDeviceHashedIds: testDeviceHashedIds,
        ),
      );
      return stateFrom(info);
    } on PlatformException catch (e) {
      AdsLogger.current.warning(
        'UMP consent gathering failed: ${e.message}',
        network: AdNetwork.admob,
      );
      return _currentState();
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await _host.showPrivacyOptions();
    } on PlatformException catch (e) {
      AdsLogger.current.warning(
        'UMP privacy options failed: ${e.message}',
        network: AdNetwork.admob,
      );
    }
  }

  @override
  Future<bool> canRequestAds() async {
    try {
      return (await _host.consentInfo()).canRequestAds;
    } on PlatformException {
      return false;
    }
  }

  /// Whether UMP requires a privacy-options entry point in the app's
  /// settings (show a button that calls [showPrivacyOptions]).
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      return (await _host.consentInfo()).privacyOptionsRequired;
    } on PlatformException {
      return false;
    }
  }

  Future<ConsentState> _currentState() async {
    try {
      return stateFrom(await _host.consentInfo());
    } on PlatformException {
      return ConsentState.unknown;
    }
  }

  /// Derives a [ConsentState] from UMP's stored IAB values.
  ///
  /// `consentGiven` is the TCF purpose-1 ("store and access information")
  /// consent bit, and is only set when GDPR applies.
  @visibleForTesting
  static ConsentState stateFrom(ConsentInfo info) {
    final gdprApplies = switch (info.gdprApplies) {
      1 => true,
      0 => false,
      _ => null,
    };
    return ConsentState(
      gdprApplies: gdprApplies,
      consentGiven: gdprApplies == true
          ? (info.purposeConsents?.startsWith('1') ?? false)
          : null,
      tcString: _nonEmpty(info.tcString),
      gppString: _nonEmpty(info.gppString),
    );
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
