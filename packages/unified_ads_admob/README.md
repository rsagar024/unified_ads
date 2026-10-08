# unified_ads_admob

Google AdMob adapter for [`unified_ads`](https://pub.dev/packages/unified_ads): banner, interstitial, rewarded, rewarded interstitial and app open ads, plus a Google UMP
`ConsentProvider`. Adding this package links **only** the Google Mobile Ads SDK and UMP into your app.

```yaml
dependencies:
  unified_ads: ^1.0.0
  unified_ads_admob: ^1.0.0
```

```dart
await UnifiedAds.requestTrackingAuthorization();
await UnifiedAds.gatherConsent(const AdmobConsentProvider());
await UnifiedAds.init(AdConfig(networks: {
  AdNetwork.admob: NetworkConfig(appId: '…', bannerAdUnitId: '…', interstitialAdUnitId: '…', rewardedAdUnitId: '…'),
}));
```

The App ID must also be in `AndroidManifest.xml` and `Info.plist`. Full setup: [`doc/setup/admob.md`](https://github.com/rsagar024/unified_ads/blob/master/doc/setup/admob.md).

| | Android | iOS |
|---|---|---|
| SDK | GMA Next-Gen `ads-mobile-sdk` 1.5.0, UMP 4.0.0 | Google-Mobile-Ads-SDK 13.11.0, UMP 3.1.0 |
| Minimum | API 24 | iOS 13 |
| Distribution | Gradle | CocoaPods + Swift Package Manager |

Status: Android verified on a physical device (banner rendered, interstitial loaded + shown, rewarded loaded); iOS compiles only in CI (`flutter build ios --no-codesign`, pending its first run) and has not yet run on a device.
New adapters copy this package: see [`TEMPLATE.md`](TEMPLATE.md).

Android uses the **GMA Next-Gen SDK**, so it can't share an app with the legacy `play-services-ads` (for example, the
official `google_mobile_ads` plugin). See the [migration note](https://github.com/rsagar024/unified_ads/blob/master/doc/migration/1.0.0-admob-next-gen.md).
**Meta (Facebook) bidding** is opt-in: add Google's Meta adapter to your app and this adapter detects it
([setup](https://github.com/rsagar024/unified_ads/blob/master/doc/setup/admob.md#7-meta-facebook-bidding-opt-in)).
