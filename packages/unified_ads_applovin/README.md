# unified_ads_applovin

AppLovin MAX adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): banner, interstitial, rewarded and app open ads. Adding this package links
**only** the AppLovin MAX SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.applovin:applovin-sdk:13.6.4` | `AppLovinSDK 13.6.4` |
| Distribution | Gradle (Maven Central) | CocoaPods + SPM |

Setup, config, privacy and error mapping: [`docs/setup/applovin.md`](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/applovin.md).

Status: Android compiles and runs on a device; there are no public MAX credentials, so serving needs your own SDK key and ad units. iOS compiles only in CI (`flutter build ios --no-codesign`, pending its first run) and has not yet run on a device.

**Meta (Facebook) bidding** is opt-in: add AppLovin's Meta adapter to your app and this adapter detects it
([setup](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/applovin.md#meta-facebook-bidding-opt-in)).
