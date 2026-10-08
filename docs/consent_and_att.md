# Consent (GDPR / US privacy / COPPA) and App Tracking Transparency

unified_ads separates **collecting** consent from **applying** it:

- A `ConsentProvider` collects consent and returns a network-neutral `ConsentState`. The provider can be Google UMP or
  your own consent management platform (CMP).
- `UnifiedAds` hands that state to every enabled adapter. Each adapter translates it to its SDK's own privacy APIs.

The core package never depends on a consent SDK, so you can swap the CMP without touching ad code. The design is in
[ARCHITECTURE.md §11](../ARCHITECTURE.md#11-consent-and-att).

## Startup order

```dart
await UnifiedAds.requestTrackingAuthorization();              // 1. iOS ATT prompt (no-op on Android)
await UnifiedAds.gatherConsent(const AdmobConsentProvider()); // 2. CMP form if required
await UnifiedAds.init(config);                                // 3. SDKs start with consent applied
```

Use **ATT → consent → init**:

1. ATT comes first because Apple requires the system prompt before any tracking. If you configure UMP's own IDFA
   explainer message in the AdMob console instead, UMP shows the ATT prompt itself; skip step 1 then.
2. Consent comes before `init` so that no SDK starts, and no SDK requests ads, before the user's choice is known.
3. A `ConsentState` set before `init` is applied during initialization. Calling `UnifiedAds.gatherConsent` or
   `UnifiedAds.updateConsent` later re-applies it to every running adapter.

## `ConsentState`

| Field | Meaning | Set by |
|---|---|---|
| `gdprApplies` | The user is in a GDPR region (`null` = unknown) | CMP |
| `consentGiven` | The user consented to personalised ads (`null` = unknown) | CMP |
| `tcString` | IAB TCF v2 string | CMP |
| `gppString` | IAB GPP string | CMP |
| `ccpaOptOut` | The user opted out of sale/sharing (US state laws) | CMP or **app** |
| `coppa` | Child-directed treatment (COPPA, or under age of consent) | **app** |

`UnifiedAds.gatherConsent` keeps the app-level signals, because a CMP cannot know them. A `coppa: true` you set earlier
stays set, and your `ccpaOptOut` is kept when the provider reports none.

```dart
await UnifiedAds.updateConsent(const ConsentState(coppa: true)); // e.g. after an age gate
```

## Google UMP (`AdmobConsentProvider`, in `unified_ads_admob`)

```dart
const provider = AdmobConsentProvider();
await UnifiedAds.gatherConsent(provider); // shows the form only when UMP requires it

// A "Privacy settings" entry in your app's settings, shown when the user is in scope:
if (await provider.isPrivacyOptionsRequired()) {
  await provider.showPrivacyOptions();
}

if (!await provider.canRequestAds()) {
  // Don't load ads yet.
}
```

- You must create the consent message in the AdMob console (**Privacy & messaging**). Without one, UMP reports a form
  error, which the provider logs. The flow then continues with the last known state.
- To test from outside the EEA:

  ```dart
  AdmobConsentProvider(
    debugGeography: UmpDebugGeography.eea,
    testDeviceHashedIds: ['<hash from logcat / Xcode console>'],
  )
  ```
- UMP writes the IAB TCF and GPP strings to `SharedPreferences` / `NSUserDefaults`. AdMob, InMobi, AppLovin MAX and
  LevelPlay read them there themselves.

## Using another CMP

Implement `ConsentProvider` and pass it to `UnifiedAds.gatherConsent`, for example for OneTrust, Didomi, Usercentrics
or your own dialog:

```dart
class MyCmpConsentProvider extends ConsentProvider {
  const MyCmpConsentProvider();

  @override
  Future<ConsentState> gather({bool forceForm = false}) async {
    // Never throw: on failure return the last known state.
    final result = await myCmp.showIfRequired(force: forceForm);
    return ConsentState(
      gdprApplies: result.gdprApplies,
      consentGiven: result.personalisedAdsAllowed,
      tcString: result.tcString,
      ccpaOptOut: result.doNotSell,
    );
  }

  @override
  Future<void> showPrivacyOptions() => myCmp.showPreferences();

  @override
  Future<bool> canRequestAds() async => myCmp.hasAnswered;
}
```

If your CMP is driven outside Flutter, call `UnifiedAds.updateConsent(state)` whenever the state changes.

## What each adapter does with the state

| Network | `consentGiven` / GDPR | `ccpaOptOut` | `coppa` | Setup |
|---|---|---|---|---|
| AdMob | TCF/GPP read by the SDK | `gad_rdp` (restricted data processing) | `AgeRestrictedTreatment.CHILD` | [admob](setup/admob.md) |
| Unity Ads | `UnityAds.userConsent` | `userOptOut` | `nonBehavioral` | [unity](setup/unity.md) |
| AppLovin MAX | `setHasUserConsent` | `setDoNotSell` | **MAX is skipped** (MAX dropped COPPA support in 13.0) | [applovin](setup/applovin.md) |
| LevelPlay | `LevelPlayPrivacySettings.setGDPRConsent` | `setCCPA` | `setCOPPA` | [ironsource](setup/ironsource.md) |
| Facebook | no API; Meta relies on your CMP / TCF | `setDataProcessingOptions(["LDU"], 0, 0)` | mixed-audience flag | [facebook](setup/facebook.md) |
| Start.io | `setUserConsent(…, "pas", …)` | `IABUSPrivacy_String` | manifest `meta-data` only (Android) | [startapp](setup/startapp.md) |
| InMobi | InMobi GDPR consent object | `InMobiPrivacyCompliance.setDoNotSell` | `InMobiSdk.setIsAgeRestricted` | [inmobi](setup/inmobi.md) |

The setup docs list the exact SDK calls per platform.

## App Tracking Transparency (iOS 14.5+)

```dart
final status = await UnifiedAds.requestTrackingAuthorization();
// notDetermined, restricted, denied, authorized, notApplicable (Android / iOS < 14), unavailable
final current = await UnifiedAds.trackingAuthorizationStatus(); // no prompt
```

- The helper lives in the core package's iOS code, so it needs no ad SDK. `AppTrackingTransparency` is weak-linked, so
  iOS 13 builds still work.
- `Info.plist` must contain `NSUserTrackingUsageDescription`. Without it iOS terminates the app when the prompt is
  requested.

  ```xml
  <key>NSUserTrackingUsageDescription</key>
  <string>This identifier will be used to deliver personalized ads to you.</string>
  ```
- iOS only shows the prompt while the app is **active**. Call the helper after the first frame, not in `main()` before
  `runApp`.
- Each network also needs its **SKAdNetwork IDs** in `Info.plist`, for attribution without the IDFA. The lists are in
  each `docs/setup/<network>.md`.
