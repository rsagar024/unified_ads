import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_ads_admob/src/messages.g.dart';
import 'package:unified_ads_admob/unified_ads_admob.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'fake_host.dart';

void main() {
  group('stateFrom', () {
    test('derives GDPR consent from the TCF purpose-1 bit', () {
      final state = AdmobConsentProvider.stateFrom(
        ConsentInfo(
          canRequestAds: true,
          privacyOptionsRequired: true,
          gdprApplies: 1,
          tcString: 'CPx',
          purposeConsents: '1011',
          gppString: '',
        ),
      );

      expect(state.gdprApplies, isTrue);
      expect(state.consentGiven, isTrue);
      expect(state.tcString, 'CPx');
      expect(state.gppString, isNull, reason: 'empty strings become null');
    });

    test('purpose 1 refused means no consent', () {
      final state = AdmobConsentProvider.stateFrom(
        ConsentInfo(
          canRequestAds: true,
          privacyOptionsRequired: false,
          gdprApplies: 1,
          purposeConsents: '0111',
        ),
      );
      expect(state.consentGiven, isFalse);
    });

    test('consent is unknown when GDPR does not apply or is unknown', () {
      expect(
        AdmobConsentProvider.stateFrom(
          ConsentInfo(
            canRequestAds: true,
            privacyOptionsRequired: false,
            gdprApplies: 0,
          ),
        ).consentGiven,
        isNull,
      );
      expect(
        AdmobConsentProvider.stateFrom(
          ConsentInfo(canRequestAds: true, privacyOptionsRequired: false),
        ),
        ConsentState.unknown,
      );
    });
  });

  test(
    'gather forwards debug settings and returns the derived state',
    () async {
      final host = FakeHost()
        ..info = ConsentInfo(
          canRequestAds: true,
          privacyOptionsRequired: false,
          gdprApplies: 1,
          purposeConsents: '1',
        );
      final provider = AdmobConsentProvider(
        debugGeography: UmpDebugGeography.eea,
        testDeviceHashedIds: const ['HASH'],
        hostApi: host,
      );

      final state = await provider.gather(forceForm: true);

      expect(host.gatherRequest?.forceForm, isTrue);
      expect(host.gatherRequest?.debugGeography, DebugGeographyMessage.eea);
      expect(host.gatherRequest?.testDeviceHashedIds, ['HASH']);
      expect(state.consentGiven, isTrue);
    },
  );

  test('gather falls back to the stored state when the flow fails', () async {
    final host = FakeHost()
      ..gatherError = PlatformException(code: 'noActivity')
      ..info = ConsentInfo(
        canRequestAds: false,
        privacyOptionsRequired: false,
        gdprApplies: 1,
        purposeConsents: '0',
      );
    final provider = AdmobConsentProvider(hostApi: host);

    final state = await provider.gather();

    expect(state.gdprApplies, isTrue);
    expect(state.consentGiven, isFalse);
    expect(await provider.canRequestAds(), isFalse);
  });

  test('privacy options helpers reach the native side', () async {
    final host = FakeHost()
      ..info = ConsentInfo(canRequestAds: true, privacyOptionsRequired: true);
    final provider = AdmobConsentProvider(hostApi: host);

    expect(await provider.isPrivacyOptionsRequired(), isTrue);
    await provider.showPrivacyOptions();
    expect(host.privacyShown, isTrue);
  });
}
