# unified_ads_unity

Unity Ads adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): banner, interstitial and rewarded ads. Adding this package links
**only** the Unity Ads SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.unity3d.ads:unity-ads:4.21.0` | `UnityAds 4.21.0` |
| Distribution | Gradle (Maven Central) | CocoaPods |

Setup, config, privacy and error mapping: [`docs/setup/unity.md`](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/unity.md).

Status: Android verified on a physical device with Unity's sample Game ID: banner, rewarded load, interstitial load + show. iOS compiles only in CI (`flutter build ios --no-codesign`, pending its first run) and has not yet run on a device.
