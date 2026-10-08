# Role & Goal

You are a senior Flutter platform engineer. Build a production-grade, open-source
Flutter plugin package (working on BOTH Android and iOS) that provides a single,
unified Dart API to load and display ads from multiple ad networks:

- AdMob (Google Mobile Ads)
- Unity Ads
- AppLovin MAX
- ironSource / Unity LevelPlay
- Meta Audience Network (Facebook)
- StartApp
- InMobi

Supported ad formats across all networks: **Banner, Interstitial, Rewarded**.
(Optional stretch: Rewarded Interstitial + App Open, behind the same interface.)

Package name: `unified_ads` (Dart package) with federated adapter packages:
unified_ads (core + public API)
unified_ads_admob
unified_ads_unity
unified_ads_applovin
unified_ads_ironsource
unified_ads_meta
unified_ads_startapp
unified_ads_inmobi
unified_ads_platform_interface

## Package identifiers

- Native base package / Android namespace / Maven group root: **`dev.arovyx.plugin.unifiedads`**
- Adapter namespaces: `dev.arovyx.plugin.unifiedads.<network>` (e.g. `dev.arovyx.plugin.unifiedads.admob`)
- Example app applicationId / iOS bundle ID: `dev.arovyx.plugin.unifiedads.example`
- Dart (pub) package names stay snake_case (`unified_ads`, `unified_ads_admob`, …) because
  pub names cannot contain dots.
- See `IMPLEMENTATION.md` for the phase-wise implementation plan.

# CRITICAL REQUIREMENT — Opt-in Networks (do not skip)

A consumer app must be able to enable ONLY the networks it wants. If a developer
wants only AdMob + Unity + InMobi, then:
- Only those 3 native SDKs must be linked/compiled into their app.
- The other 4 SDKs must NOT be present in the final AAR/IPA.
- No linker warnings, no unused pod dependencies, no Gradle pulls of other SDKs.

Design this with a federated plugin architecture + `AdNetworkAdapter` interface.
Use `implements`/`extends` on a platform-interface package. Explain in the
architecture doc exactly how Gradle dependencies and CocoaPods subspecs are pulled
in per adapter package, and how the core package avoids depending on any adapter.

Also provide an ALTERNATIVE single-package mode driven by build flags
(`--dart-define=ADS_NETWORKS=admob,unity,inmobi` + Gradle flavor / Podfile
conditionals) for teams that prefer one package. Document trade-offs.

# Configuration Requirements

Each developer supplies their own credentials per network and per ad format.
Config must support:
- App-level IDs (AdMob App ID, Unity Game ID, MAX SDK key, ironSource App Key,
  Meta App ID, StartApp App ID, InMobi Account ID / Placement ID)
- Ad-unit / placement IDs per format (banner, interstitial, rewarded) per network
- Test-mode flag (global AND per-network) that forces test ads
- Waterfall / priority ordering of networks
- Optional per-network enable flag and per-format enable flag

Provide config via BOTH:
1. A Dart `AdConfig` object (programmatic, most flexible)
2. A `pubspec.yaml` `unified_ads:` section OR `ads_config.json` asset
   (declarative, generated to Dart via a code-gen or build-time loader)

Example config shape to document:
```dart
AdConfig(
  testMode: true,
  waterfall: [AdNetwork.admob, AdNetwork.unity, AdNetwork.inmobi],
  networks: {
    AdNetwork.admob: NetworkConfig(
      appId: 'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy',
      bannerAdUnitId: '...',
      interstitialAdUnitId: '...',
      rewardedAdUnitId: '...',
    ),
    // ...
  },
)
```

# Public Dart API

Design a clean, idiomatic, null-safe Dart 3 API. At minimum:

- `UnifiedAds.init(AdConfig)` / `UnifiedAds.isInitialized`
- Banner: `BannerAd` + `UnifiedBannerWidget` (Flutter widget, PlatformView-based,
  supports standard / adaptive / inline sizes, anchored & inline anchoring)
- Interstitial: `load()`, `show()`, `isReady`, callbacks
- Rewarded: `load()`, `show()`, `isReady`, `RewardItem` (amount + type), callbacks
- Unified callbacks/events: onLoaded, onFailedToShow, onShown, onClicked,
  onClosed, onEarnedReward, onImpression
- Unified `AdError` model with `code`, `message`, `network`, `nativeCode`
- Caching + preloading API (preload next interstitial/rewarded automatically)
- Frequency capping option
- Manual waterfall helper: if network A fails, try network B automatically
- Dispose / lifecycle handling; no leaks; safe on hot restart

Every ad class must expose which network actually served the ad.

# Native Layer

- Use **Pigeon** (preferred) or MethodChannel + EventChannel.
- Write Android in **Kotlin** and iOS in **Swift**.
- Android: minSdk 23 (document if a network needs higher), Gradle 8.x,
  AGP 8.x, namespace declaration, ProGuard/R8 consumer rules per adapter.
- iOS: iOS 13+ deployment target, Podfile instructions, `use_frameworks!`
  compatibility notes, static vs dynamic framework notes.
- Handle banner rendering via PlatformView (AndroidView / UiKitView) with
  correct sizing, safe-area, and no touch-eating issues.
- Correct threading: all UI work on main thread; Dart callbacks marshalled properly.
- Proper Activity/ViewController lifecycle awareness (pause/resume, rotation,
  detach).

# Platform Setup Docs (must be generated)

Per network, write exact setup steps:
- AndroidManifest / Info.plist entries (e.g. AdMob App ID meta-data, Unity Game ID)
- SKAdNetwork IDs list for iOS + `NSUserTrackingUsageDescription`
- ATT (App Tracking Transparency) request helper API in Dart
- GDPR/UMP consent flow integration (Google UMP) with a documented abstraction
  so other consent SDKs can be plugged in
- Cleartext traffic / network security config notes if required by any network

# IMPORTANT — Verify Before Coding

Before writing code, research and state clearly in a `SDK_STATUS.md`:
- The CURRENT latest stable SDK version of each of the 7 networks (Android + iOS)
- Any deprecation, wind-down, merger, or rename (e.g. Unity Ads + ironSource →
  Unity LevelPlay, Meta Audience Network changes)
- Minimum OS versions each SDK requires
- Whether each SDK supports banner / interstitial / rewarded natively
  If a network cannot support a format or is discontinued, implement the adapter
  as a documented stub and explain why. Do NOT silently invent API names.

# Engineering Standards

- Flutter 3.x, Dart 3, sound null safety, `flutter_lints` + strict analysis_options
- Full repo structure with melos OR pure pub workspaces (justify choice)
- Unit tests (mocked adapters), widget tests for banner widget, integration test
  in example app
- GitHub Actions CI: analyze, test, build example APK + iOS build (no signing)
- README (with feature matrix table), CHANGELOG, LICENSE (MIT), CONTRIBUTING
- pub.dev readiness: dartdoc comments on every public symbol, package scoring
  checklist (pana), example folder required
- Error handling: never crash host app; all native exceptions mapped to AdError
- Logging: a pluggable `AdsLogger` with levels, silent by default

# Example App

Build a full example app with:
- A settings screen where the user CHECKS which networks to enable
- Text fields to enter App IDs and Ad-unit IDs per format per network
- Save config (persist with shared_preferences) and re-init
- Buttons to load/show banner, interstitial, rewarded
- A live event log console showing every callback with timestamps
- A "network selector" for the banner widget so user can force a specific network

# Delivery Order (do this, do not dump all code at once)

1. Ask me up to 5 clarifying questions ONLY if something blocks you. Otherwise
   proceed with sensible defaults and state assumptions.
2. Deliverable 1: `ARCHITECTURE.md` (diagram in ASCII/mermaid, adapter interface
   contract, package dependency graph, how opt-in linking works on Android & iOS)
3. Deliverable 2: `SDK_STATUS.md` (verified SDK research table)
4. Deliverable 3: `unified_ads_platform_interface` + `unified_ads` core public API
   (Dart only, with stub platform implementation so it compiles)
5. Deliverable 4: ONE complete adapter end-to-end (AdMob) including native
   Kotlin + Swift code — this becomes the template.
6. Deliverable 5: remaining 6 adapters following the same template.
7. Deliverable 6: example app, tests, CI, docs.

At each deliverable, list files created and how to run them. Flag any decision
where you had to guess an SDK API so I can verify it.

# Non-negotiables

- Must build and run on both Android and iOS.
- Selecting a subset of networks must genuinely exclude the other SDKs.
- No hardcoded real ad unit IDs in the package itself (test IDs only in example).
- No breaking changes to the public API without a documented migration note.