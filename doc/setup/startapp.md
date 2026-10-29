# Start.io setup (`unified_ads_startapp`)

> **Getting the IDs:** how to create the account, app and every ID for this network is in
> [doc/getting_ids.md](../getting_ids.md#startio).

| Platform | SDK (pinned) | Minimum |
|---|---|---|
| Android | `com.startapp:inapp-sdk:5.4.0` | API 23 per AAR (project: 24) |
| iOS | `StartAppSDK` 4.15.0 (Swift Package Manager: official `StartApp-SDK/StartAppSDK-SwiftPackage`, product `StartApp`) | iOS 11 per its `Package.swift` (project: 13) |

## Config

```dart
AdNetwork.startapp: NetworkConfig(
  appId: '<Start.io App ID>',
  // Optional: Start.io has no per-format ad units. A value here is sent as the
  // "ad tag" for reporting (Android and iOS full-screen ads).
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
- **COPPA is manifest-only on Android.** For child-directed or mixed-audience apps, Start.io's integration docs require BOTH:

  ```xml
  <manifest xmlns:android="http://schemas.android.com/apk/res/android"
      xmlns:tools="http://schemas.android.com/tools">
      <!-- Flag, read by the SDK before init: -->
      <meta-data android:name="com.startapp.sdk.CHILD_DIRECTED" android:value="true"/>
      <!-- The SDK's AAR merges ACCESS_WIFI_STATE; for child-directed apps it must
           be removed again via the manifest merger (official "App Permissions
           (COPPA Compliant)" step): -->
      <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" tools:node="remove"/>
  </manifest>
  ```

  Use `MIXED_AUDIENCE` instead when the app serves everyone including children; both must be set before the SDK initializes.
  There's no documented iOS COPPA API.
- **Optional:** Start.io's own disclosure/consent dialog is shown by default. If your app handles consent centrally (UMP or
  another CMP), you can suppress it in your app manifest with `<meta-data android:name="com.startapp.sdk.CONSENT_ENABLED"
  android:value="false"/>` ⚠ (the key is read by SDK 5.4.0's meta-data reader; only add it if your consent UX already
  covers Start.io's disclosure).

## Platform notes

- **Android:** Maven Central. Setup is fully automatic except for **one required entry in your app's manifest** (below):
  - `com.startapp.sdk.APPLICATION_ID` meta-data is NOT needed (the App ID is passed in code).
  - **Required — remove the SDK's auto-init provider.** This adapter uses Start.io's **Code Initialization** path, and
    Start.io's official integration docs make the provider removal a mandatory step for that path: otherwise
    `StartAppInitProvider` initializes the SDK at process start (with no App ID) before `UnifiedAds.init` runs. Add this
    inside the `<application>` element:

    ```xml
    <manifest xmlns:android="http://schemas.android.com/apk/res/android"
        xmlns:tools="http://schemas.android.com/tools">
        <application …>
            <provider
                android:name="com.startapp.sdk.adsbase.StartAppInitProvider"
                android:authorities="${applicationId}.startappinitprovider"
                tools:node="remove" />
        </application>
    </manifest>
    ```

    (A `tools:node="remove"` in the adapter's own library manifest is not honored by the manifest merger — verified
    with AGP 9.0.1 — which is why this step lives in the app manifest.)
  - The AAR merges its own permissions — INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, RECEIVE_BOOT_COMPLETED,
    `com.google.android.gms.permission.AD_ID` (so API 31+ targets are covered), ACCESS_ADSERVICES_TOPICS and the
    install-referrer permission — plus its activities/services and ProGuard rules (`com.startapp.**`). The official
    docs' optional `BLUETOOTH` permission is not merged and not needed by this adapter.
- **iOS:** add `SKAdNetworkItems` (Start.io's own ID is `5l3tpt7t6e.skadnetwork`; full list:
  https://www.start.io/skadnetworkids.json) and `NSUserTrackingUsageDescription`
  (the SDK links AppTrackingTransparency).

## Errors

- **Android** exposes no numeric error codes: load failures map to `noFill` with the SDK's message, and "not displayed"
  maps to `showFailed`.
- **iOS** reports `STAError` codes (4.15.0 `STAErrorCodes.h`), and `AdError.nativeCode` carries the number:

  | `STAError` | `AdErrorCode` |
  |---|---|
  | 1 NoInternetConnection | `networkError` |
  | 3 AppIDNotSet, 4 InvalidParams, 6 ExpectedAdParamsMissingOrInvalid | `invalidConfig` |
  | 7 AdTypeNotSupported | `unsupportedFormat` |
  | 0 Unexpected, 2 Internal | `internal` |
  | 5 AdRules, 12 NoContent, others (load) | `noFill` |
  | show: 8 AdAlreadyDisplayed / 9 AdExpired, 10 AdNotReady | `alreadyShowing` / `notReady` |
  | show: other | `showFailed` |

## API names used

- ✅ **Android: compiler-verified** against 5.4.0:
  - `StartAppSDK.initParams(ctx, appId).setReturnAdsEnabled(false).setCallback{}.init()`
  - `StartAppAd.loadAd(AdMode, AdPreferences, AdEventListener)`, `showAd(AdDisplayListener)`, `setVideoListener`
  - `Banner` / `Mrec(ctx, AdPreferences, BannerListener)`
  - `AdPreferences.setAdTag`
- ⚠ **iOS: not yet compiled.** The 4.15.0 headers have no `NS_SWIFT_NAME`s, so delegate methods are pinned to their
  Objective-C selectors with `@objc(...)`. The headers declare `initializeWithAppID:completion:`,
  `setUserConsent:forConsentType:withTimestamp:` and `handleExtras:`; their Swift spellings
  (`initialize(withAppID:completion:)`, …) follow the importer's rules but aren't shown in Start.io's Swift sample.
  The ad tag uses `STAAdPreferences.adTag` with `loadAdWithDelegate:withAdPreferences:` /
  `loadRewardedVideoAdWithDelegate:withAdPreferences:`, called by selector name. Banners don't send the tag on iOS yet.
  ⚠ The unit of the iOS consent timestamp isn't documented (the adapter sends seconds; Android's sample uses
  milliseconds).
