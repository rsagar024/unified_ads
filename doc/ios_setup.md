# iOS setup (all networks)

What an iOS app that uses `unified_ads` needs, per network. Run the checker on your app to confirm:

```bash
dart run tool/verify_ios_plist.dart \
  --plist ios/Runner/Info.plist \
  --networks admob,unity,inmobi \
  --privacy ios/Runner/PrivacyInfo.xcprivacy   # optional
```

It exits **1** if a required entry is missing and **2** on bad usage or an unreadable file. It is pure Dart, so it runs on
Windows and Linux too, and it only reads XML plists (Xcode's default; convert a binary plist with
`plutil -convert xml1`). The rules live in `tool/src/ios_plist_rules.dart`; keep them in sync with this page.
`tool/verify_ios_plist.dart --list-skadnetwork-ids --networks …` prints the SKAdNetwork IDs that the checker expects.

## 1. Deployment target and Podfile

| Adapter | Min iOS | Why |
|---|---|---|
| `unified_ads` (core), admob, unity, applovin, ironsource, startapp, inmobi | 13.0 | plugin floor (the SDKs themselves need ≤ 13; see [SDK_STATUS.md](../SDK_STATUS.md)) |
| `unified_ads_facebook` | **15.0** | Audience Network 6.22 |

Flutter's Podfile template leaves the platform commented out (iOS 13 default). Set it explicitly, or `pod install`
fails as soon as `unified_ads_facebook` is added:

```ruby
# ios/Podfile
platform :ios, '15.0'   # 13.0 if you don't use unified_ads_facebook
```

Also raise **Runner → Build Settings → iOS Deployment Target** to the same value. The example app commits
[`example/ios/Podfile`](../example/ios/Podfile) for this reason.

- **Xcode:** 26.2+ (Google Mobile Ads 13.4+ requires it; UnityAds 4.18+ requires 26.0.1+).
- **`use_frameworks!`:** works both ways. Every adapter pod is `static_framework = true` (the vendor SDKs ship static
  or xcframework binaries), and CI builds dynamic (Flutter's default) and `use_frameworks! :linkage => :static`.
- **Swift Package Manager:** admob, applovin, ironsource, facebook and the core ship `Package.swift`; unity, startapp and
  inmobi are CocoaPods-only, so Flutter uses its mixed mode when they are present. CI builds both modes
  (`tool/ios_build.sh spm|cocoapods-dynamic|cocoapods-static`).

## 2. Info.plist keys

### Every app

| Key | Required? | Why |
|---|---|---|
| `NSUserTrackingUsageDescription` | **required** (checker) | Text of the ATT prompt shown by `UnifiedAds.requestTrackingAuthorization()`. Requesting tracking without it crashes the app. |
| `SKAdNetworkItems` | **required** for each network's own ID (below) | SKAdNetwork install attribution. Production apps should add each network's full partner list (links below). |

### Per network

| Network | Required keys | Own SKAdNetwork ID(s) (checker) | Full list / source |
|---|---|---|---|
| AdMob | `GADApplicationIdentifier` (your iOS App ID, `ca-app-pub-…~…`): the SDK throws at launch without it | `cstr6suwn9.skadnetwork` | [quick start](https://developers.google.com/admob/ios/quick-start), [3p SKAdNetworks](https://developers.google.com/admob/ios/3p-skadnetworks) |
| Unity Ads | none (Game ID is passed in code) | `4dzt52r2t5.skadnetwork` | [configure ad network IDs](https://docs.unity.com/en-us/ads-ios/4.18.0/privacy/ios14/configure-ad-network-ids), JSON: `https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json` |
| AppLovin MAX | none (SDK key is passed in code; older guides mention an `AppLovinSdkKey` row, which this plugin does not use) | `ludvb6z3bs.skadnetwork` | [SKAdNetwork](https://support.applovin.com/en/max/ios/overview/skadnetwork), [JSON](https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json) / [XML](https://skadnetwork-ids.applovin.com/v1/skadnetworkids.xml) |
| ironSource / LevelPlay | none (app key in code) | `su67r6k2v3.skadnetwork` | [LevelPlay SKAdNetwork ID manager](https://docs.unity.com/grow/levelplay/sdk/ios/skadnetwork-id-manager) |
| Facebook Audience Network | none | `v9wttpbfk9.skadnetwork`, `n38lu8286q.skadnetwork` | [Meta SKAdNetwork](https://developers.facebook.com/docs/audience-network/setting-up/platform-setup/ios/SKAdNetwork) (these two are the whole list) |
| Start.io | none (the adapter passes the App ID in code; `com.startapp.sdk.APPLICATION_ID` is an Info.plist alternative used by Start.io's own Flutter plugin) | ⚠ **not enforced**: Start.io's own ID could not be confirmed from a public source (its list sits behind a support login) | [iOS 14 readiness](https://support.start.io/hc/en-us/articles/360017903540-iOS-14-Readiness) |
| InMobi | none (account ID in code) | `wzmmz9fp6w.skadnetwork` (from Unity's LevelPlay network table) | [InMobi iOS guidelines](https://support.inmobi.com/monetize/sdk-documentation/ios-guidelines/overview-ios-guidelines) (hosts the full buyer list) |

Example (`ios/Runner/Info.plist`):

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~IIIIIIIIII</string>
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
<key>SKAdNetworkItems</key>
<array>
  <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
  <dict><key>SKAdNetworkIdentifier</key><string>4dzt52r2t5.skadnetwork</string></dict>
  <!-- … one dict per ID … -->
</array>
```

No network needs an App Transport Security exception for this plugin's SDK versions. The LevelPlay demo app sets
`NSAllowsArbitraryLoads`, but that is not required.

## 3. ATT (App Tracking Transparency)

Call `UnifiedAds.requestTrackingAuthorization()` after the consent flow and before initializing (see
[consent_and_att.md](consent_and_att.md)). It needs `NSUserTrackingUsageDescription` and returns `TrackingStatus.notApplicable` below
iOS 14. Audience Network 6.15+ reads the ATT status itself on iOS 17+, so the deprecated
`setAdvertiserTrackingEnabled` is not called.

## 4. Privacy manifests

- **SDK manifests:** every vendor SDK ships its own `PrivacyInfo.xcprivacy`. Each `unified_ads` package bundles one too
  (`<package>_privacy` resource bundle; the core's was added in 1.0.1). The packages themselves collect nothing.
- **App manifest:** Xcode merges all of these into the privacy report, but the **app** still declares what it does with
  the data. An app that shows ads with the IDFA should have an app-level `ios/Runner/PrivacyInfo.xcprivacy` (add it to
  the Runner target) with:

| Key | Typical value for an ad-supported app |
|---|---|
| `NSPrivacyTracking` | `true` (the checker warns if not) |
| `NSPrivacyTrackingDomains` | the domains your app itself contacts for tracking (often empty) |
| `NSPrivacyCollectedDataTypes` | at least `NSPrivacyCollectedDataTypeDeviceID` and `…AdvertisingData` with purpose `NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising` (the checker warns if no entry has that purpose) |
| `NSPrivacyAccessedAPITypes` | the required-reason APIs your own code uses (for example `UserDefaults` via `shared_preferences`, reason `CA92.1`) |

With `--privacy`, the checker requires all four keys and warns about the two points above. The example's manifest is
[`example/ios/Runner/PrivacyInfo.xcprivacy`](../example/ios/Runner/PrivacyInfo.xcprivacy). Your answers in App Store
Connect's privacy section must match it.

## 5. Verifying without a Mac

`.github/workflows/ios.yml` runs on free GitHub macOS runners, with no signing and no Apple account. For the root
example and for a scratch app per adapter, it:

1. checks the Info.plist with this tool;
2. runs `flutter build ios --simulator --no-codesign`;
3. boots a simulator and runs `flutter drive` with `integration_test/ad_smoke_test.dart` against public test IDs
   ([getting_ids.md](getting_ids.md#public-test-ids-used-by-ci));
4. uploads screenshots and logs as the `ios-sim-<target>` artifacts.

Fork the repo and the workflow runs on your fork too. On a Mac: `bash tool/ios_sim_smoke.sh all|<network>`.
Results: [SDK_STATUS.md](../SDK_STATUS.md#0-verification-status).
