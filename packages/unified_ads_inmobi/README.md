# unified_ads_inmobi

InMobi adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): banner, interstitial and rewarded ads. Adding this package links
**only** the InMobi SDK into your app.

| | Android | iOS |
|---|---|---|
| SDK | `com.inmobi.monetization:inmobi-ads-kotlin:11.5.0` | `InMobiSDK 11.5.0` |
| Distribution | Gradle (Maven Central) | CocoaPods |

Setup, config, privacy and error mapping: [`docs/setup/inmobi.md`](https://github.com/rsagar024/unified_ads/blob/main/docs/setup/inmobi.md).

Status: Android: the SDK initializes and requests round-trip on a device; InMobi's sample placements return NO_FILL for this package, so serving needs your own placements (dashboard test mode). iOS compiles only in CI (`flutter build ios --no-codesign`, pending its first run) and has not yet run on a device.
