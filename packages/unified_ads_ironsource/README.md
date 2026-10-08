# unified_ads_ironsource

ironSource / Unity LevelPlay adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): banner, interstitial and rewarded ads. Adding this package links
**only** the ironSource / Unity LevelPlay SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.unity3d.ads-mediation:mediation-sdk:9.6.1` | `IronSourceSDK 9.6.1.0` |
| Distribution | Gradle (Maven Central) | CocoaPods + SPM |

Setup, config, privacy and error mapping: [`docs/setup/ironsource.md`](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/ironsource.md).

Status: Android: the SDK initializes and requests round-trip on a device; LevelPlay's demo key returns no fill for this package, so serving needs your own app key. iOS compiles only in CI (`flutter build ios --no-codesign`, pending its first run) and has not yet run on a device.

**Meta (Facebook) bidding** is opt-in: add LevelPlay's Meta adapter (and Audience Network on Android) to your app and
this adapter detects it ([setup](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/ironsource.md#meta-facebook-bidding-opt-in)).
