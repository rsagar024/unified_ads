import 'package:flutter/foundation.dart';

/// Privacy signals forwarded to every adapter.
///
/// `null` fields mean "unknown / not applicable"; adapters leave the
/// corresponding SDK setting untouched. IAB TCF / GPP strings written to
/// platform storage by a CMP are also read directly by several SDKs.
///
/// ## Tamper evidence
///
/// [signature] and [issuer] allow adapters to verify that a [ConsentState]
/// originated from the app's CMP and was not forged by a compromised
/// dependency. When present, adapters should verify [signature] against the
/// app's CMP public key identified by [issuer] before applying the consent
/// state. If verification fails, adapters should treat the consent as
/// unknown and not forward personalized-ad signals to the native SDK.
///
/// At minimum, [ConsentState] should only be constructed by the app's CMP
/// integration; adapters should not accept consent states with a
/// [signature] they cannot verify.
@immutable
class ConsentState {
  /// Creates a consent state.
  ///
  /// [signature] is an optional cryptographic signature over the consent
  /// fields, produced by the app's CMP. [issuer] identifies the CMP that
  /// produced the signature, so adapters can look up the correct public key.
  const ConsentState({
    this.gdprApplies,
    this.consentGiven,
    this.tcString,
    this.gppString,
    this.ccpaOptOut,
    this.coppa = false,
    this.signature,
    this.issuer,
  });

  /// Nothing is known yet.
  static const unknown = ConsentState();

  /// Whether GDPR applies to the user.
  final bool? gdprApplies;

  /// Whether the user consented to personalized ads.
  final bool? consentGiven;

  /// IAB TCF v2 consent string, if a CMP produced one.
  final String? tcString;

  /// IAB GPP string, if a CMP produced one.
  final String? gppString;

  /// Whether the user opted out of the sale of personal data (CCPA / US
  /// state laws).
  final bool? ccpaOptOut;

  /// Whether the app or user is child-directed (COPPA). Some networks must not
  /// be initialized at all in this case (AppLovin MAX).
  final bool coppa;

  /// Optional cryptographic signature over the consent fields, produced by
  /// the app's CMP. Adapters should verify this against the CMP public key
  /// identified by [issuer] before applying the consent state.
  final String? signature;

  /// Identifier of the CMP that produced [signature], used to look up the
  /// correct public key for verification.
  final String? issuer;

  /// Returns a copy with the given fields replaced.
  ConsentState copyWith({
    bool? gdprApplies,
    bool? consentGiven,
    String? tcString,
    String? gppString,
    bool? ccpaOptOut,
    bool? coppa,
    String? signature,
    String? issuer,
  }) {
    return ConsentState(
      gdprApplies: gdprApplies ?? this.gdprApplies,
      consentGiven: consentGiven ?? this.consentGiven,
      tcString: tcString ?? this.tcString,
      gppString: gppString ?? this.gppString,
      ccpaOptOut: ccpaOptOut ?? this.ccpaOptOut,
      coppa: coppa ?? this.coppa,
      signature: signature ?? this.signature,
      issuer: issuer ?? this.issuer,
    );
  }

  /// Whether this consent state carries a verifiable [signature] from a
  /// known [issuer]. Returns `false` when either field is missing.
  bool get isSigned => signature != null && issuer != null;

  @override
  bool operator ==(Object other) =>
      other is ConsentState &&
      other.gdprApplies == gdprApplies &&
      other.consentGiven == consentGiven &&
      other.tcString == tcString &&
      other.gppString == gppString &&
      other.ccpaOptOut == ccpaOptOut &&
      other.coppa == coppa &&
      other.signature == signature &&
      other.issuer == issuer;

  @override
  int get hashCode => Object.hash(
    gdprApplies,
    consentGiven,
    tcString,
    gppString,
    ccpaOptOut,
    coppa,
    signature,
    issuer,
  );

  @override
  String toString() =>
      'ConsentState(gdprApplies: $gdprApplies, consentGiven: $consentGiven, '
      'ccpaOptOut: $ccpaOptOut, coppa: $coppa, signature: $signature, '
      'issuer: $issuer)';
}

/// A consent management platform (CMP) integration.
///
/// `unified_ads_admob` ships a Google UMP implementation. Apps using another
/// CMP implement this interface and pass the result to
/// `UnifiedAds.gatherConsent`.
abstract class ConsentProvider {
  /// Allows subclasses to have `const` constructors.
  const ConsentProvider();

  /// Refreshes consent information and shows the consent form if required
  /// (or always, when [forceForm] is true). Never throws; on failure returns
  /// the last known state.
  Future<ConsentState> gather({bool forceForm = false});

  /// Shows the CMP's privacy-options form, if the CMP provides one.
  Future<void> showPrivacyOptions();

  /// Whether ads may be requested under the current consent state.
  Future<bool> canRequestAds();
}
