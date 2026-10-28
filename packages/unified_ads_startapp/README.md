# unified_ads_startapp

[![CI](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ci.yaml)
[![iOS simulator](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml/badge.svg)](https://github.com/rsagar024/unified_ads/actions/workflows/ios.yml)
[![pub package](https://img.shields.io/pub/v/unified_ads_startapp.svg)](https://pub.dev/packages/unified_ads_startapp)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/rsagar024/unified_ads/blob/master/LICENSE)

Start.io adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): **banner, interstitial and rewarded** ads.
Adding this package links **only** the Start.io SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.startapp:inapp-sdk:5.4.0` | `StartAppSDK` 4.15.0 |
| Minimum | API 23 per AAR (package: 24) | iOS 9 (package: 13) |
| Distribution | Gradle (Maven Central) | Swift Package Manager (`StartApp-SDK/StartAppSDK-SwiftPackage`, product `StartApp`) |

## Install and use

```yaml
dependencies:
  unified_ads: ^1.1.0
  unified_ads_startapp: ^1.1.0
```

```dart
await UnifiedAds.init(AdConfig(
  testMode: true,
  networks: {
    AdNetwork.startapp: NetworkConfig(
      appId: PlatformValue.select(android: '<Android App ID>', ios: '<iOS App ID>'),
      // Optional: Start.io has no per-format ad units. A value here is sent as the
      // "ad tag" for reporting (Android).
      interstitialAdUnitId: 'level_end',
      extras: {'rewardAmount': 1, 'rewardType': 'reward'},  // Start.io rewards carry no amount
    ),
  },
));
```

## Getting the IDs

You need: App ID only.

1. **Account:** register at the Start.io publisher portal.
2. **App ID:** **Add New App** → paste the store link, or **Haven't published your app yet?** → name + platform. The App
   ID is shown right away and under **My Apps**.
3. **Ad tags (optional):** there are no ad unit IDs. A value in `bannerAdUnitId` / `interstitialAdUnitId` /
   `rewardedAdUnitId` is sent as a free-form **ad tag** (letters, ≤ 200 chars) that appears in reports.
4. **Testing:** `testMode: true` enables test ads. **Disable it in production**, or the app won't monetize. Minimum payout $50.

## Notes

- **App ID only:** the adapter declares `requiresAdUnitId = false`, so every format serves without unit IDs.
- **Splash and return ads:** the Android SDK shows these by default; the adapter disables both at init
  (`setReturnAdsEnabled(false)`, `StartAppAd.disableSplash()`). On iOS 4.15 both are deprecated no-ops.
- **Test mode** (`TestModeSupport.flag`): `setTestAdsEnabled` / `testAdsEnabled`. **Turn it off in production**, or the
  app won't monetize.
- **Rewards:** Start.io reports a completed video, not an amount; the adapter reports `extras['rewardAmount']` /
  `extras['rewardType']`.
- **Banners:** 320×50 `Banner`, or 300×250 `Mrec` for `BannerSize.mediumRectangle`; other sizes fall back to 320×50.
  Start.io banners have no destroy API; the view is detached on dispose.
- **Impressions:** on Android the full-screen `adDisplayed` callback is reported as both `shown` and `impression`; iOS has
  a dedicated impression callback.

## Platform setup

- **Android:** the AAR ships its ProGuard rules and permissions. `com.startapp.sdk.APPLICATION_ID` meta-data is not
  needed (the App ID is passed in code).
- **iOS:** `SKAdNetworkItems` from https://www.start.io/skadnetworkids.json and `NSUserTrackingUsageDescription` (the SDK
  links AppTrackingTransparency).

## Privacy

- `consentGiven` → `setUserConsent(…, "pas", timestamp, granted)` (milliseconds on Android, seconds on iOS).
- `ccpaOptOut` → `IABUSPrivacy_String` (`1YYN` for opt-out, `1YNN` otherwise) in the Start.io extras.
- **COPPA is manifest-only on Android:**
  `<meta-data android:name="com.startapp.sdk.CHILD_DIRECTED" android:value="true"/>` (or `MIXED_AUDIENCE`). There's no
  documented iOS COPPA API.

## Errors

Start.io exposes no numeric error codes. Load failures map to `noFill` with the SDK's message; "not displayed" maps to
`showFailed`.

## Status

Android verified on a physical device with Start.io's demo App ID: banner, rewarded load, interstitial load + show. iOS
builds in CI and hasn't run on a physical device yet.

---

Part of [`unified_ads`](https://pub.dev/packages/unified_ads): one Dart API for banner, interstitial and rewarded ads across seven networks, linking only the SDKs you add. Its [README](https://github.com/rsagar024/unified_ads/blob/master/packages/unified_ads/README.md) is the full guide: configuration, waterfall, consent and ATT, every network's setup, architecture and SDK status.

## License

MIT, see [LICENSE](https://github.com/rsagar024/unified_ads/blob/master/LICENSE).
