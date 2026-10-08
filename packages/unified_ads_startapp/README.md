# unified_ads_startapp

Start.io adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): banner, interstitial and rewarded ads. Adding this package links
**only** the Start.io SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.startapp:inapp-sdk:5.4.0` | `StartAppSDK 4.15.0` |
| Distribution | Gradle (Maven Central) | CocoaPods |

Setup, config, privacy and error mapping: [`docs/setup/startapp.md`](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/startapp.md).

Status: Android verified on a physical device with Start.io's demo App ID: banner, rewarded load, interstitial load + show. iOS compiles only in CI (`flutter build ios --no-codesign`, pending its first run) and has not yet run on a device.
