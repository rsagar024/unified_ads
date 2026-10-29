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

## 1. Swift Package Manager and deployment target

Since **1.1.0**, every `unified_ads` package is **Swift Package Manager only** on iOS; CocoaPods is not supported.
You need Flutter **3.44+** with SPM enabled (the default on stable; `flutter config --enable-swift-package-manager`).
Upgrading from 1.0.x: see [`doc/migration/1.1.0-swift-package-manager.md`](migration/1.1.0-swift-package-manager.md).

| Adapter | Min iOS | Why |
|---|---|---|
| `unified_ads` (core), admob, unity, applovin, ironsource, startapp, inmobi | 13.0 | plugin floor (the SDKs themselves need ≤ 13; see [SDK_STATUS.md](../SDK_STATUS.md)) |
| `unified_ads_facebook`, or any Meta bidding adapter | **15.0** | Audience Network 6.22 |

Set the deployment target in Xcode: open `ios/Runner.xcworkspace`, select the **Runner** project and **Runner** target,
and set **Build Settings → iOS Deployment Target** (`IPHONEOS_DEPLOYMENT_TARGET`) to 15.0 if you use
`unified_ads_facebook` (13.0 otherwise). With 13.0, the build fails as soon as `unified_ads_facebook` is added.

- **Xcode:** 26.2+ (Google Mobile Ads 13.4+ requires it; UnityAds 4.18+ requires 26.0.1+).
- **Swift packages:** each adapter's `ios/<package>/Package.swift` declares its vendor's official Swift package (exact
  pin; see [SDK_STATUS.md](../SDK_STATUS.md)), so only the adapters you depend on are resolved. Check
  `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`. CI builds one configuration (`tool/ios_build.sh`).
- **Other CocoaPods plugins:** if another plugin in your app is still CocoaPods-only, keep its `Podfile`; Flutter's
  mixed mode builds that plugin through CocoaPods while the `unified_ads` packages come through SPM. Don't add pods for
  unified_ads networks there.
- **`-ObjC`:** InMobi and LevelPlay **require** it, and their own Swift packages can't set it, so add `-ObjC` to
  **Runner → Build Settings → Other Linker Flags** when you use either. The inmobi and ironsource manifests also pass
  it (⚠ whether that reaches the app link is to be confirmed by CI). InMobi additionally needs `libz`, `libsqlite3.0`
  and `WebKit`, which its adapter's manifest links.

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
| Facebook Audience Network | none | `v9wttpbfk9.skadnetwork`, `n38lu8286q.skadnetwork` | [Meta SKAdNetwork](https://developers.facebook.com/documentation/audience-network/setting-up/platform-setup/ios/SKAdNetwork) (these two are the whole list) |
| Start.io | none (the adapter passes the App ID in code; `com.startapp.sdk.APPLICATION_ID` is an Info.plist alternative used by Start.io's own Flutter plugin) | `5l3tpt7t6e.skadnetwork` (the `Start.io` entry of its published list) | [JSON](https://www.start.io/skadnetworkids.json), [iOS 14 readiness](https://support.start.io/hc/en-us/articles/360017903540-iOS-14-Readiness) |
| InMobi | none (account ID in code) | `wzmmz9fp6w.skadnetwork` | [JSON](https://www.inmobi.com/skadnetworkids.json), [InMobi iOS guidelines](https://support.inmobi.com/monetize/sdk-documentation/ios-guidelines/overview-ios-guidelines) |

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

**App Transport Security:** InMobi's and LevelPlay's iOS guides recommend `NSAppTransportSecurity` →
`NSAllowsArbitraryLoads = YES` (for HTTP creatives); the other networks need no exception. It's a recommendation, not
something the plugin depends on, and App Review may ask you to justify it, so add it only if you use those networks
and accept that trade-off.

## 3. ATT (App Tracking Transparency)

Call `UnifiedAds.requestTrackingAuthorization()` first, before the consent flow and initialization (**ATT → consent →
init**, see [consent_and_att.md](consent_and_att.md)). It needs `NSUserTrackingUsageDescription` and returns
`TrackingStatus.notApplicable` below iOS 14. For Audience Network (`unified_ads_facebook`, or Meta bidding through
AdMob / MAX / LevelPlay), the adapters set `FBAdSettings.setAdvertiserTrackingEnabled` from the ATT status on iOS 15–16,
as Meta requires; on iOS 17+ Audience Network 6.15+ reads the status itself.

## 4. Privacy manifests

- **SDK manifests:** every vendor SDK ships its own `PrivacyInfo.xcprivacy`. Each `unified_ads` package bundles one too
  (an SPM resource bundle, `<package>_<package>.bundle`; it was `<package>_privacy` under CocoaPods in 1.0.x). The
  packages themselves collect nothing.
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
Results: [SDK_STATUS.md](../SDK_STATUS.md).
