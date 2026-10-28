# unified_ads_inmobi

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_inmobi.svg)](https://pub.dev/packages/unified_ads_inmobi)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

InMobi adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial and rewarded** ads.
Adding this package links **only** the InMobi SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.inmobi.monetization:inmobi-ads-kotlin:11.5.0` (the Java artifact `inmobi-ads` is abandoned) | `InMobiSDK` 11.5.0 |
| Minimum | API 21 (package: 24); **Kotlin 2.x, AGP ≥ 8.9.3** | iOS 12 (package: 13) |
| Distribution | Gradle (Maven Central) | Swift Package Manager (`InMobi/InMobiSDK-Swift-Package`, product `InMobiSDK`) |

## Install and use

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_inmobi: ^1.1.0
```

```dart
await UnifiedAds.init(AdConfig(
  networks: {
    AdNetwork.inmobi: NetworkConfig(
      appId: '<InMobi account ID>',
      bannerAdUnitId: '1234567890',         // placement IDs are NUMERIC (validated at init)
      interstitialAdUnitId: '1234567890',
      rewardedAdUnitId: '1234567890',       // a Rewarded Video placement
    ),
  },
));
```

## Getting the IDs

You need: Account ID + numeric placement ID per format.

1. **Account:** InMobi publisher dashboard → **Create Account** → verify email. Add an app and a payment method to reach
   **Pending Approval** (about 24 working hours).
2. **Account ID:** top-left corner, under your account name.
3. **App:** **Inventory → Inventory Settings → Add Inventory** → Mobile App (store URL) or Unpublished App.
4. **Placements:** expand the app → **+ Add a placement** → **Banner** / **Interstitial** / **Rewarded Video** (with a
   reward key/value, e.g. `Coins` = `1000`). The long numeric **Placement ID** is under the name.
5. **Testing:** no code-level test flag. Turn test mode on **per placement** (Global or Device) and register devices
   under **Integration → Integration Testing**. With `testMode: true` the adapter logs at DEBUG so your advertising ID is
   printed. **Turn test mode off before release.**

## Notes

- **Test mode** (`TestModeSupport.none`): no code-level test flag. Enable test mode per placement in the InMobi
  dashboard ("Global ON", or "Selective ON" with your device ID). With `testMode` on, the adapter switches InMobi logging
  to DEBUG so the device ID is printed; unified_ads logs a warning at init.
- **Rewarded:** the reward is the first entry of InMobi's rewards map (`name → amount`), as configured on the dashboard.
- **Banner sizes:** no adaptive size. MREC is 300×250, leaderboard 728×90, everything else 320×50.
- **Activity:** InMobi needs an Activity to show interstitials, so full-screen ads load only while one is attached
  (otherwise `noActivity`).

## Platform setup

- **Android:** every dependency (OkHttp, Picasso, media3, coroutines, …) comes through the POM; the AAR ships its ProGuard
  rules and merges its activities and permissions. Keep `android:hardwareAccelerated="true"`.
- **iOS:** `SKAdNetworkItems` (own ID `wzmmz9fp6w.skadnetwork`; full list from InMobi's iOS guidelines) and
  `NSUserTrackingUsageDescription`. InMobi recommends `NSAllowsArbitraryLoads = YES`; flag it for App Store review. It's a
  dynamic xcframework that needs `-ObjC`: the adapter's `Package.swift` passes it; if you see undefined symbols, add
  `-ObjC` to the Runner target's Other Linker Flags.

## Privacy

IAB TCF / GPP strings from a CMP (e.g. UMP) are read automatically (SDK 10.7.5+). Explicitly: `consentGiven` /
`gdprApplies` → InMobi's GDPR consent object, `ccpaOptOut` → `InMobiPrivacyCompliance.setDoNotSell`, `coppa` →
`InMobiSdk.setIsAgeRestricted`.

## Error mapping (`InMobiAdRequestStatus.StatusCode` / `IMStatusCode`)

| Status | `AdErrorCode` |
|---|---|
| NO_FILL, AD_NO_LONGER_AVAILABLE | `noFill` |
| NETWORK_UNREACHABLE, SERVER_ERROR | `networkError` |
| REQUEST_TIMED_OUT | `timeout` |
| REQUEST_INVALID, CONFIGURATION_ERROR, MONETIZATION_DISABLED, MISSING_REQUIRED_DEPENDENCIES | `invalidConfig` |
| AD_ACTIVE | `alreadyShowing` |
| other | `internal` |

## Status

Android: the SDK initializes and requests round-trip on a device; InMobi's sample placements return NO_FILL for this
package, so serving needs your own placements (dashboard test mode). iOS builds in CI and hasn't run on a physical device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
