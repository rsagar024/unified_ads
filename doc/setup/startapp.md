# Start.io setup (`unified_ads_startapp`)

> **Getting the IDs:** how to create the account, app and every ID for this network is in
> [doc/getting_ids.md](../getting_ids.md#startio).

| Platform | SDK (pinned) | Minimum |
|---|---|---|
| Android | `com.startapp:inapp-sdk:5.4.0` | API 23 per AAR (project: 24) |
| iOS | `StartAppSDK` 4.15.0 (**CocoaPods only**) | iOS 9 (project: 13) |

## Config

```dart
AdNetwork.startapp: NetworkConfig(
  appId: '<Start.io App ID>',
  // Optional: Start.io has no per-format ad units. A value here is sent as the
  // "ad tag" for reporting (Android).
  interstitialAdUnitId: 'level_end',
  extras: {'rewardAmount': 1, 'rewardType': 'reward'},  // Start.io rewards carry no amount
),
```

- **App ID only:** the adapter declares `requiresAdUnitId = false`, so Start.io serves every format without unit IDs.
- **Splash and return ads:** the Android SDK shows these automatically by default. The adapter disables both at init
  (`setReturnAdsEnabled(false)`, `StartAppAd.disableSplash()`). On iOS 4.15 both features are deprecated no-ops.
- **Test mode** (`TestModeSupport.flag`): `setTestAdsEnabled` / `testAdsEnabled`. **Turn it off in production**, or the
  app won't monetize.
- **Rewards:** Start.io reports a completed video, not an amount. The adapter reports `extras['rewardAmount']` /
  `extras['rewardType']`.
- **Banners:** 320×50 `Banner`, or a 300×250 `Mrec` for `BannerSize.mediumRectangle`. There's no adaptive banner, so other
  sizes fall back to 320×50. Start.io banners have no destroy API; the view is detached on dispose.
- **Impressions:** the full-screen `adDisplayed` callback is reported as both `shown` and `impression` (Android). iOS has
  a dedicated impression callback.

## Privacy

- `consentGiven` calls `setUserConsent(…, "pas", timestamp, granted)`. The timestamp is milliseconds on Android and seconds on iOS.
- `ccpaOptOut` writes `IABUSPrivacy_String` (`1YYN` for opt-out, `1YNN` otherwise) to the Start.io extras.
- **COPPA is manifest-only on Android:** add `<meta-data android:name="com.startapp.sdk.CHILD_DIRECTED" android:value="true"/>`
  (or `MIXED_AUDIENCE`) to your app manifest. There's no documented iOS COPPA API.

## Platform notes

- **Android:** Maven Central. The AAR ships its ProGuard rules and permissions. `com.startapp.sdk.APPLICATION_ID` meta-data is not
  needed, because the App ID is passed in code.
- **iOS:** add `SKAdNetworkItems` from https://www.start.io/skadnetworkids.json and `NSUserTrackingUsageDescription`
  (the pod links AppTrackingTransparency).

## Errors

Start.io exposes no numeric error codes. Load failures map to `noFill` with the SDK's message; "not displayed" maps to
`showFailed`.

## API names used

- ✅ **Android: compiler-verified** against 5.4.0:
  - `StartAppSDK.initParams(ctx, appId).setReturnAdsEnabled(false).setCallback{}.init()`
  - `StartAppAd.loadAd(AdMode, AdPreferences, AdEventListener)`, `showAd(AdDisplayListener)`, `setVideoListener`
  - `Banner` / `Mrec(ctx, AdPreferences, BannerListener)`
  - `AdPreferences.setAdTag`
- ⚠ **iOS: not yet compiled.** Delegate methods are pinned to their Objective-C selectors with `@objc(...)`.
  `initialize(withAppID:completion:)`, `setUserConsent(_:forConsentType:withTimestamp:)` and `handleExtras` are inferred
  Swift spellings.
