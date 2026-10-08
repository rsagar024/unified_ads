# unified_ads: Implementation Plan

This is the phase-wise roadmap for building the `unified_ads` federated Flutter plugin described in
`CLAUDE.md`. It covers **what** gets built, **in which order**, **which files** each phase
produces, and **how each phase is verified**. It contains no implementation code.

> Status (2026-10-08): **Phases 0–7 delivered (Phase 7: RI + App Open, AdMob Android on GMA Next-Gen, opt-in Meta bidding). Phases 0–5 complete on Android. Device serving is verified for AdMob,
Start.io and Unity Ads; LevelPlay
> and InMobi round-trip to no-fill with demo credentials; AppLovin MAX needs an owner key. Opt-in
linking is verified. Facebook Audience Network is now a full adapter
> (owner request; banner + interstitial test ads serve; bidding-only in production). The Phase 5
example app tests every network from one screen (verified on device). Phase 6 delivered CI, the
> opt-in check script, pub.dev metadata, docs and the config CLI; everything that can run on Windows passes. The
> GitHub Actions run itself (iOS build, iOS opt-in check, pana) awaits the first push.** Deferred at owner request:
> `git init` and the `.gitignore` update.

---

## 1. Overview & Scope

| Item               | Scope                                                                                                                               |
|--------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| Networks           | AdMob, Unity Ads, AppLovin MAX, ironSource / Unity LevelPlay, Facebook Audience Network (branded Meta), StartApp (Start.io), InMobi |
| Formats (required) | Banner, Interstitial, Rewarded                                                                                                      |
| Formats (stretch)  | Rewarded Interstitial, App Open                                                                                                     |
| Platforms          | Android (Kotlin), iOS (Swift)                                                                                                       |
| Bridge             | Pigeon (typed host/flutter APIs)                                                                                                    |
| Architecture       | Federated plugin: core + platform interface + one package per network                                                               |
| Alternative mode   | Single package with networks selected by build flags (documented, secondary)                                                        |

**Non-negotiables** (from CLAUDE.md):

1. It must build and run on Android and iOS.
2. Selecting a subset of networks must **genuinely exclude** the other SDKs from the APK/AAB/IPA.
3. No real ad-unit IDs in any package. Test IDs appear only in `example/`.
4. The host app never crashes because of an ad. Every native exception maps to `AdError`.
5. Public API changes ship with a migration note.

---

## 2. Identifiers & Naming

| Dart package (pub)               | Android namespace / package               | iOS plugin class                                                 | Pod / SwiftPM target                             |
|----------------------------------|-------------------------------------------|------------------------------------------------------------------|--------------------------------------------------|
| `unified_ads`                    | `dev.arovyx.plugin.unifiedads`            | `UnifiedAdsPlugin`                                               | `unified_ads`                                    |
| `unified_ads_platform_interface` | *(pure Dart, no native code)*             | n/a                                                              | n/a                                              |
| `unified_ads_admob`              | `dev.arovyx.plugin.unifiedads.admob`      | `UnifiedAdsAdmobPlugin`                                          | `unified_ads_admob`                              |
| `unified_ads_unity`              | `dev.arovyx.plugin.unifiedads.unity`      | `UnifiedAdsUnityPlugin`                                          | `unified_ads_unity`                              |
| `unified_ads_applovin`           | `dev.arovyx.plugin.unifiedads.applovin`   | `UnifiedAdsApplovinPlugin`                                       | `unified_ads_applovin`                           |
| `unified_ads_ironsource`         | `dev.arovyx.plugin.unifiedads.ironsource` | `UnifiedAdsIronsourcePlugin`                                     | `unified_ads_ironsource`                         |
| `unified_ads_facebook`           | `dev.arovyx.plugin.unifiedads.facebook`   | `UnifiedAdsFacebookPlugin` (+ `FacebookAdapter` dartPluginClass) | `unified_ads_facebook`                           |
| `unified_ads_startapp`           | `dev.arovyx.plugin.unifiedads.startapp`   | `UnifiedAdsStartappPlugin`                                       | `unified_ads_startapp`                           |
| `unified_ads_inmobi`             | `dev.arovyx.plugin.unifiedads.inmobi`     | `UnifiedAdsInmobiPlugin`                                         | `unified_ads_inmobi`                             |
| `example` app                    | `dev.arovyx.plugin.unifiedads.example`    | n/a                                                              | bundle ID `dev.arovyx.plugin.unifiedads.example` |

- Dart package names stay snake_case because pub names cannot contain dots.
- Pigeon-generated channel names are prefixed `dev.arovyx.plugin.unifiedads.<network>.` so adapters
  never collide.
- PlatformView view types use the format `dev.arovyx.plugin.unifiedads/<network>/banner`.

---

## 3. Assumptions & Open Decisions

| #   | Decision                         | Default chosen                                                                                                                    | Reason / to confirm                                                                                                                                                                                                                                                                                                                                    |
|-----|----------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| A1  | Monorepo tooling                 | **Dart pub workspaces** (`workspace:` in root pubspec) + **melos 8.x** for scripts only                                           | Pub workspaces give one resolution and one lockfile natively (Dart ≥ 3.6). Melos adds `analyze`/`test`/`publish` fan-out scripts and versioning. Melos ≥ 7 reads its config from the root `pubspec.yaml` `melos:` key, so there is **no `melos.yaml`**. Melos is a root dev dependency and runs as `dart run melos …`, so no global install is needed. |
| A2  | Native bridge                    | **Pigeon**                                                                                                                        | Type-safe, generates Kotlin + Swift, and handles main-thread marshalling consistently.                                                                                                                                                                                                                                                                 |
| A3  | Android toolchain                | ✅ **minSdk 24**, AGP 9.x, Kotlin 2.3.x (current Flutter template)                                                                 | **Resolved by Phase 1 research:** AdMob 25.5.0 and AppLovin MAX 13.6.3+ require minSdk 24, so CLAUDE.md's minSdk 23 / AGP 8.x is superseded. Kotlin ≥ 2.1 (AdMob, InMobi) and compileSdk ≥ 35 are satisfied. See SDK_STATUS §3.4.                                                                                                                      |
| A4  | iOS distribution                 | ✅ **CocoaPods for every adapter; SwiftPM where the vendor ships SPM**                                                             | Vendor SPM exists for AdMob, UMP, LevelPlay and MAX. Start.io and InMobi are CocoaPods-only, and Unity Ads SPM is ⚠. Those adapters are CocoaPods-only, and Flutter's mixed mode handles them.                                                                                                                                                         |
| A5  | iOS minimum                      | ✅ iOS 13                                                                                                                          | All adapters support iOS 13 except `unified_ads_facebook`, which needs **iOS 15** (FBAudienceNetwork 6.22). CI needs **Xcode 26.2+** ⚠ (AdMob 13.4+).                                                                                                                                                                                                  |
| A6  | Declarative config               | `ads_config.json` asset + runtime loader (no build_runner required); `pubspec.yaml` section is optional via a small CLI generator | Simpler for consumers, and it works with hot restart.                                                                                                                                                                                                                                                                                                  |
| A7  | Consent                          | Abstract `ConsentProvider` with a Google UMP implementation in `unified_ads_admob`                                                | Lets other CMPs plug in. Core does not depend on UMP.                                                                                                                                                                                                                                                                                                  |
| A8  | SDK versions                     | ✅ **Pinned exactly as in `SDK_STATUS.md` §1** (no `+` ranges)                                                                     | Verified 2026-10-07. Re-verify before each adapter release.                                                                                                                                                                                                                                                                                            |
| A9  | AdMob Android SDK                | ✅ **GMA Next-Gen `ads-mobile-sdk` 1.5.0** (Phase 7, owner: "switch fully", 2026-10-08; was legacy 25.5.0)                         | Google has put it in maintenance mode in favour of GMA Next-Gen (`ads-mobile-sdk` 1.5.0). Migrated in Phase 7 (`doc/migration/1.0.0-admob-next-gen.md`).                                                                                                                                                                                                       |
| A10 | Facebook Audience Network (Meta) | ✅ **Full direct adapter** (owner reversal, 2026-10-07; first decided as a documented stub the same day)                           | Bidding-only since 2021: direct loads serve test ads but aren't expected to fill in production; documented prominently. Revenue via mediation bidding: **opt-in Meta bidding glue in the AdMob, MAX and LevelPlay adapters (Phase 7)**.                                                                                                                                                                            |
| A11 | Unity Ads + LevelPlay together   | ✅ **Runtime-exclusive**                                                                                                           | Unity doesn't support direct and mediated Unity Ads in one process. Core reports `configConflict` and skips `unity` when both are enabled.                                                                                                                                                                                                             |

---

## 4. Target Repository Layout

```
unified_ads/                      (repo root = pub workspace root)
├─ pubspec.yaml                   (workspace: [...] + melos: config, no code)
├─ analysis_options.yaml          (strict, shared; packages inherit it)
├─ CLAUDE.md  IMPLEMENTATION.md  ARCHITECTURE.md  SDK_STATUS.md
├─ README.md  CHANGELOG.md  LICENSE  CONTRIBUTING.md
├─ doc/
│  ├─ setup/<network>.md          (manifest, Info.plist, SKAdNetwork, R8 notes)
│  ├─ consent_and_att.md
│  ├─ single_package_mode.md
│  └─ migration/
├─ packages/
│  ├─ unified_ads/                (core public API; current root scaffold moves here)
│  ├─ unified_ads_platform_interface/
│  ├─ unified_ads_admob/          (android/, ios/, lib/, pigeons/, test/)
│  ├─ unified_ads_unity/
│  ├─ unified_ads_applovin/
│  ├─ unified_ads_ironsource/
│  ├─ unified_ads_facebook/
│  ├─ unified_ads_startapp/
│  └─ unified_ads_inmobi/
├─ example/                       (full demo app + integration_test/)
└─ .github/workflows/ci.yaml
```

---

## 5. Phase-wise Plan

Every phase lists: **Goal → Tasks → Files → Exit criteria → ⚠ Verify-SDK-API flags**.
No phase starts until the previous phase's exit criteria are met and you have reviewed it.

### Phase 0: Repository Bootstrap

**Goal:** Turn the single `flutter create` scaffold into a workspace skeleton.

Tasks:

- 0.1 ✅ Create the root workspace `pubspec.yaml` with the melos config under its `melos:` key (
  scripts: `analyze`, `test`, `format`, `pigeon`, `build:example`).
- 0.2 ✅ Rename identifiers `com.example.unified_ads` → `dev.arovyx.plugin.unifiedads`.
- 0.3 ✅ Move the root scaffold (`lib/`, `test/`, `android/`, `ios/`, `pubspec.yaml`, `README.md`,
  `CHANGELOG.md`, `unified_ads.iml`) into `packages/unified_ads/`. Delete the template
  method-channel code and the stale `pubspec.lock` / `example/pubspec.lock`.
- 0.4 ✅ Create package shells for the platform interface and the 7 adapters (`pubspec.yaml` with
  `resolution: workspace`, placeholder `lib/<pkg>.dart`, README, CHANGELOG, LICENSE).
- 0.5 ✅ Set up a strict root `analysis_options.yaml` (`flutter_lints` + `strict-casts`,
  `strict-inference`, `strict-raw-types`, `public_member_api_docs`, async-safety lints).
- 0.6 ◐ LICENSE (MIT) ✅, CONTRIBUTING ✅. `.gitignore` update and `git init` are **deferred at owner
  request** (no git yet).

Files: root `pubspec.yaml`, `analysis_options.yaml`, `packages/*/pubspec.yaml`, `LICENSE`,
`CONTRIBUTING.md`.
Exit: `flutter pub get` resolves the workspace, and `dart run melos run analyze` passes on all
packages.

#### Phase 0 progress log (2026-10-07)

**Done**

- `LICENSE`: MIT, copyright "The unified_ads Authors". ⚠ Confirm the copyright holder (e.g. Arovyx).
  The file is copied into every package because pub requires a LICENSE per package.
- `CONTRIBUTING.md`: setup, layout, the 7 repository rules, and the PR checklist.
- `analysis_options.yaml` (root): strict profile. **Deviation from 0.4:** packages do not get their
  own `analysis_options.yaml`. They inherit the root file because the analyzer walks up
  directories (the same pattern flutter/packages uses), which avoids 9 copies drifting apart.
  `example/` keeps its own file.
- `packages/unified_ads_platform_interface/` and
  `packages/unified_ads_{admob,unity,applovin,ironsource,meta,startapp,inmobi}/`: shells.
    - `publish_to: none` until homepage/repository URLs exist (Phase 6).
    - SDK constraint `^3.12.2`, `flutter: '>=3.44.0'`, matching the current toolchain. This can be
      lowered later if wider compatibility is wanted.
    - Adapter shells deliberately have **no `flutter: plugin:` section and no `android/` or `ios/`
      folders yet**. Declaring a `pluginClass` without native code would break app builds. Native
      scaffolding arrives with each adapter in Phase 3/4.

- Root `pubspec.yaml` (`unified_ads_workspace`, `publish_to: none`): a 10-member workspace (core +
  interface + 7 adapters + example), `melos: ^8.9.0` dev dependency, and melos scripts.
- `packages/unified_ads/`: the moved scaffold. Its pubspec now uses `resolution: workspace` and
  depends on `unified_ads_platform_interface` instead of `plugin_platform_interface`.
  `lib/unified_ads.dart` holds a documented placeholder `UnifiedAds` class. Kotlin and Swift
  `UnifiedAdsPlugin` are no-op plugins (the template `getPlatformVersion` channel was removed). The
  package has its own LICENSE (the podspec references `../LICENSE`), README, and CHANGELOG.
- `example/`: `resolution: workspace`, depends on `../packages/unified_ads`, and has a placeholder
  `main.dart` plus updated widget and integration tests.

**Verified (exit criterion met)**

- `flutter pub get` resolves the workspace with a single root `pubspec.lock`.
- `dart run melos run analyze` (`--fatal-infos`): *No issues found* in all 10 packages.
- `dart run melos run test`: core and example tests pass.
- Not yet verified: native builds (`flutter build apk` / iOS). The native code is a trivial no-op;
  the first real build check happens in Phase 3.

**Deferred at owner request**

- `git init`, plus a `.gitignore` update to commit the root `pubspec.lock` for reproducible
  example/CI builds.

### Phase 1: Research & Architecture Docs (CLAUDE.md Deliverables 1 & 2)

**Goal:** Lock down the design and verified SDK facts **before any code**. See the detailed
checklist in §6.

Files: `ARCHITECTURE.md`, `SDK_STATUS.md`, `doc/single_package_mode.md` (draft).
Exit: You have reviewed both docs, and every network has a decision: **full adapter**, **partial
adapter** (some formats stubbed), or **documented stub**.

**Status (2026-10-07): documents delivered; awaiting the §6.3 review gate.** Per-network decisions:

| Network                   | Decision                   | Formats                                   | Key constraint                                                                     |
|---------------------------|----------------------------|-------------------------------------------|------------------------------------------------------------------------------------|
| AdMob                     | Full                       | B/I/R (+ RI, App Open as stretch)         | Android legacy SDK 25.5.0 (A9); the App ID must be in manifest/plist at build time |
| Unity Ads                 | Full                       | B/I/R; RI/App Open stubbed                | 4.19+ instance APIs only; exclusive with LevelPlay (A11)                           |
| AppLovin MAX              | Full                       | B/I/R (+ App Open as stretch); RI stubbed | SDK key passed in code; refuses init when COPPA applies                            |
| ironSource / LevelPlay    | Full                       | B/I/R; RI/App Open stubbed                | 9.x `LevelPlay*` APIs only; test mode is test-suite only                           |
| Facebook Audience Network | Full (bidding-only caveat) | B/I/R; RI/App Open stubbed                | Test ads only without bidding (A10); iOS 15; app must allow cleartext to 127.0.0.1 |
| Start.io                  | Full                       | B/I/R; RI/App Open stubbed                | App ID only; splash and return ads disabled by the adapter                         |
| InMobi                    | Full                       | B/I/R; RI/App Open stubbed                | Numeric placement IDs; test mode is dashboard-only                                 |

### Phase 2: Platform Interface + Core Dart API (Deliverable 3)

**Goal:** The complete public Dart API compiles and is fully unit-tested against fake adapters, with
no native code yet.

`unified_ads_platform_interface`:

- Enums/models: `AdNetwork`, `AdFormat`, `AdConfig`, `NetworkConfig`, `BannerSize` (standard /
  adaptive / inline), `AdError` (`code`, `message`, `network`, `nativeCode`), `RewardItem` (
  `amount`, `type`), `AdEvent` sealed hierarchy (loaded, failedToLoad, failedToShow, shown, clicked,
  closed, earnedReward, impression).
- `AdNetworkAdapter` abstract contract as specified in `ARCHITECTURE.md` §5: `initialize`, `load`/
  `show`/`isReady`/`destroy` (format-generic), `bannerViewType` + `bannerCreationParams`,
  `applyConsent`, `dispose`, `supportedFormats`, `testModeSupport`, and an event stream.
- Init-time guards: Unity + LevelPlay conflict (A11), MAX + COPPA, and a warning for networks whose
  `testModeSupport` can't force test ads.
- `AdapterRegistry` (adapters self-register via `registerWith()` from Flutter's plugin registrant).
- `ConsentProvider`, `TrackingAuthorization` (ATT) interfaces.
- `AdsLogger` with levels, silent by default.

`unified_ads` (core):

- `UnifiedAds.init(AdConfig)`, `UnifiedAds.isInitialized`, `UnifiedAds.dispose()`, safe re-init on
  hot restart.
- `InterstitialAd`, `RewardedAd`: `load()`, `show()`, `isReady`, callbacks, `servedBy` (network).
- `BannerAd` + `UnifiedBannerWidget` (PlatformView host, sizing, inline/anchored, `forceNetwork`).
- `WaterfallEngine`: ordered fallback across networks, per-network timeout, skips disabled
  networks/formats.
- `AdCache`: preload next interstitial/rewarded, expiry handling.
- `FrequencyCap`: per format, count per time window.
- `AdConfigLoader`: loads `ads_config.json`, validates it, and merges it with programmatic
  overrides.
- `ErrorMapper`: guarantees that nothing reaches the app except `AdError`.

Tests: unit tests for config validation, waterfall order and fallback, cache, frequency cap, error
mapping, and lifecycle; widget tests for `UnifiedBannerWidget` using a fake view type.
Exit: `melos run analyze && melos run test` is green, and the public API dartdoc is complete. *
*Publish an API review to you before Phase 3.**

#### Phase 2 progress log (2026-10-07)

**Verified:** `dart run melos run format` (0 changed), `dart run melos run analyze` (
`--fatal-infos`, all 10 packages:
no issues), `dart run melos run test` (85 tests: 17 platform interface + 67 core + 1 example, all
passing).

**API review summary.** These are the public symbols, and the source of truth is the dartdoc in
code.

| Package                          | Public API                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `unified_ads_platform_interface` | `AdNetwork`, `AdFormat`, `AdErrorCode`, `AdError`, `AdResult` / `AdSuccess` / `AdFailure`, `RewardItem`, `AdHandle`, sealed `AdEvent` (`AdLoaded`, `AdFailedToLoad`, `AdFailedToShow`, `AdShown`, `AdImpression`, `AdClicked`, `AdClosed`, `AdEarnedReward`, `BannerSized`), `BannerSize` / `BannerSizeType`, `BannerRequest`, `PlatformValue`, `NetworkConfig`, `FrequencyCap`, `PreloadPolicy`, `AdConfig`, `ConsentState`, `ConsentProvider`, `TrackingStatus`, `TrackingAuthorization`, `TestModeSupport`, `AdsLogger` / `AdsLogLevel` / `AdsLogRecord` / `AdsLogSink` / `maskId`, `AdNetworkAdapter`, `AdapterRegistry`, `UnsupportedAdNetworkAdapter` |
| `unified_ads`                    | re-exports the interface, plus `UnifiedAds` (static facade), `InitResult`, `InterstitialAd`, `RewardedAd` (+ `RewardCallback`), `FullScreenAd` (+ `AdCallback`, `AdErrorCallback`), `BannerAd` / `BannerAdState` / `BannerAttempt`, `UnifiedBannerWidget` (+ `BannerPlatformViewBuilder`, `buildBannerPlatformView`), `AdConfigLoader`, `FrequencyStore` / `InMemoryFrequencyStore`                                                                                                                                                                                                                                                                         |
| `unified_ads/testing.dart`       | `FakeAdNetworkAdapter` (scriptable fake for app and adapter tests)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |

**Decisions made while implementing (for your review)**

- `load()` and `show()` return `AdResult<void>` *and* fire callbacks, so the API never throws for
  expected failures. `show()`
  completes on presentation; `onClosed` signals dismissal.
- **Preload semantics:** `PreloadPolicy(formats: {interstitial, rewarded})` (the default) refills
  the cache after close.
  `onInit: true` also preloads at init, and `UnifiedAds.preload(format)` preloads on demand.
- `AdConfig.waterfall` empty means every configured network in `AdNetwork` order. A non-empty list
  is exhaustive; other
  networks serve only via `forceNetwork`.
- A waterfall with a single failure returns that network's own error. Multiple failures return
  `noFill` with `attempts`.
- Added `AdNetworkAdapter.requiresAdUnitId` (Start.io) and `ConsentProvider.canRequestAds()` →
  `Future<bool>`.
  ARCHITECTURE.md §5/§6/§7/§11 is updated to match.
- `UnifiedBannerWidget` does not dispose its `BannerAd`; the owner does. It collapses to zero size
  when every network fails
  (`collapseWhenFailed`).
- **ATT:** the Dart side (`MethodChannelTracking`, channel `dev.arovyx.plugin.unifiedads/tracking`)
  is done and returns
  `unavailable` until the native iOS helper lands in Phase 3.

**Bugs found and fixed by the tests**

- A refill deadlocked: `whenComplete` waited on its own future.
- Expired cached ads were skipped but never destroyed, which leaked native ads.
- The init/dispose lock held a long-lived future that hung callers from other zones. This would have
  hung app
  developers' `testWidgets` tests that call `UnifiedAds.init`. The lock is now zone-safe.

**Deferred:** `RewardedInterstitialAd` / `AppOpenAd` classes (Phase 7; `FullScreenAd` already
supports the formats),
native ATT (Phase 3), and the pubspec → JSON config CLI (Phase 6).

### Phase 3: AdMob Reference Adapter (Deliverable 4, the template)

**Goal:** One network end-to-end on both platforms. It defines the pattern every other adapter
copies.

Tasks:

- `pigeons/admob_api.dart` → generated Dart, Kotlin, and Swift.
- SDKs: `com.google.android.gms:play-services-ads:25.5.0` and UMP `4.0.0` (Android);
  `Google-Mobile-Ads-SDK` 13.11.0 and `GoogleUserMessagingPlatform` 3.1.0 (iOS, CocoaPods + SPM).
- First, verify that `dartPluginClass` registration works without `implements:` (ARCHITECTURE §3).
- Android (Kotlin): `UnifiedAdsAdmobPlugin` (FlutterPlugin + ActivityAware), init,
  interstitial/rewarded controllers, `BannerPlatformViewFactory` (adaptive sizing, no touch-eating),
  and main-thread dispatch. Activity attach/detach/config-change handling. `consumer-rules.pro`. The
  SDK dependency is declared **only** in this package's `build.gradle.kts`.
- iOS (Swift): plugin, controllers, `FlutterPlatformViewFactory` banner, root-view-controller
  lookup, safe-area handling. The SDK dependency is declared **only** in this package's podspec /
  `Package.swift`.
- UMP consent implementation of `ConsentProvider`; the ATT helper lives in core iOS.
- `doc/setup/admob.md`: manifest meta-data, Info.plist `GADApplicationIdentifier`, SKAdNetwork IDs,
  `NSUserTrackingUsageDescription`.
- `TEMPLATE.md` in the package: a checklist for creating the next adapter.

Exit: the example app loads and shows AdMob test banner/interstitial/rewarded ads on an Android
emulator and iOS simulator. The APK contains no other network's classes.
⚠ Flag every AdMob/UMP API name used, for your verification against `SDK_STATUS.md`.

#### Phase 3 progress log (2026-10-07)

**Delivered**

- `packages/unified_ads_admob`:
    - Pigeon 29 schema plus generated Dart, Kotlin and Swift.
    - `AdmobAdapter` and the UMP-based `AdmobConsentProvider`.
    - Kotlin: plugin, full-screen ads, banner `PlatformViewFactory`, UMP, and error mapping.
    - Swift: the same pieces, plus the podspec, `Package.swift` and privacy manifest.
    - Consumer R8 rules, `TEMPLATE.md`, README and CHANGELOG.
- **Core:**
    - Native iOS ATT helper (`UnifiedAdsPlugin.swift`; ATT weak-linked in the podspec).
    - `UnifiedAds.gatherConsent` now keeps app-level `coppa`/`ccpaOptOut` (a CMP cannot know them),
      with a new test.
- **Example:**
    - AdMob sample App IDs in the manifest and Info.plist, plus `SKAdNetworkItems` and the ATT usage
      string.
    - Minimal demo screen (ATT → UMP → init; banner, interstitial and rewarded buttons; event log).
    - Device integration test.
- **Docs:** `doc/setup/admob.md`. SDK_STATUS §2.1 gained the implementation check (verified and ⚠
  names), and
  ARCHITECTURE §5.1 the Pigeon notes.

**Verified**

- Format: 0 files changed. Analyze: no issues across all packages. Dart tests: 107 passing (17 + 68
  core + 20 AdMob + 2 example).
- Kotlin unit tests: `./gradlew :unified_ads_admob:testDebugUnitTest`, 3 passing.
- `flutter build apk --debug` succeeded, so the Kotlin compiles against `play-services-ads` 25.5.0
  and UMP 4.0.0.
- The generated `dart_plugin_registrant.dart` calls `AdmobAdapter.registerWith()` on Android and iOS
  **without**
  `implements:`. This confirms ARCHITECTURE §3.
- **Opt-in linking:** `:app:dependencies --configuration releaseRuntimeClasspath` contains only
  `play-services-ads(-api,-identifier)`
  and `user-messaging-platform`. No Unity, AppLovin, ironSource, Meta, Start.io or InMobi artifacts.
- **On device**, a physical CPH1931 (Android 10):
  `flutter test integration_test/plugin_integration_test.dart -d 84795e12`
  passed:
    - init ready;
    - a real adaptive banner rendered via Hybrid Composition, with `bannerSized` + `loaded`;
    - a rewarded test ad loaded;
    - an interstitial test ad loaded **and presented**, with `shown` received in Dart.

**Not yet verified**

- **iOS (owner decision: wait for CI).** The Swift, podspec and `Package.swift` are uncompiled until
  the Phase 6 macOS job
  (`flutter build ios --no-codesign`).
- **Showing a rewarded ad through to reward + close needs a person** to watch and dismiss it. On a
  device it is covered by
  load only. The reward/close event path is covered by unit and integration tests with a faked
  native side. To check by hand,
  run `flutter run -d 84795e12` in `example/` and tap **Load rewarded → Show rewarded**.
- The UMP form needs a message configured in the AdMob console for the real App ID. With the sample
  App ID, UMP reports a
  form error, which the flow logs and continues past.

**Found during the phase**

- The shell's `JAVA_HOME` points at `…\jbr\bin` instead of `…\jbr`. Flutter builds are unaffected,
  but running `gradlew`
  directly needs `JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"`. Fix it in your
  environment when convenient.

### Phase 4: Remaining Six Adapters (Deliverable 5)

**Goal:** Clone the template for Unity, AppLovin MAX, ironSource/LevelPlay, Facebook Audience
Network, StartApp, and InMobi.

Per adapter: Pigeon schema, Kotlin + Swift implementation, banner PlatformView, R8 rules, setup doc,
and SKAdNetwork IDs. A format the SDK does not support is implemented as a stub that returns
`AdError(code: unsupportedFormat)` and is documented. Versions and API names come from
`SDK_STATUS.md`. Each ⚠ item in SDK_STATUS §3.5 is verified before that adapter is coded.
Suggested order (least to most uncertain): AppLovin MAX → InMobi → ironSource/LevelPlay → Unity
Ads (iOS instance-API names ⚠) → Start.io. **Meta** is a stub package (Dart only, no native SDK,
returns `unsupportedNetwork`, with a README explaining the bidding-only status and the mediation
path).
Exit: each adapter passes its own unit tests plus a manual smoke test in the example app. ⚠ Each
adapter's doc lists the guessed or verified API names.

#### Phase 4 progress log (2026-10-07)

**Delivered**

- **Shared base: `BridgedAdNetworkAdapter`** (platform interface). It implements the adapter
  contract once (never throwing,
  `PlatformException` → `AdError`, loaded-ad tracking, native-event translation).
  `unified_ads_admob` was refactored onto it with
  no behaviour change: its 20 tests still pass and the file went from ~260 to ~110 lines.
- **Five full adapters:** `unified_ads_applovin`, `unified_ads_inmobi`, `unified_ads_ironsource`,
  `unified_ads_unity`,
  `unified_ads_startapp`. Each has:
    - a Pigeon schema plus generated code;
    - a Dart adapter (generated from one template);
    - Kotlin: plugin, full-screen ads, banner `PlatformViewFactory`, `Errors` + JUnit test;
    - Swift: plugin, banner, ordered event queue;
    - a podspec (exact pin), plus `Package.swift` for MAX and LevelPlay (the vendors with official
      SPM packages);
    - consumer R8 rules, a privacy manifest, README / CHANGELOG, and `doc/setup/<network>.md`.
- **`unified_ads_facebook`** (renamed from `unified_ads_meta`, see below): first a Dart-only
  documented stub; **upgraded to a full adapter the same day** (see "Facebook adapter upgrade"
  below). As a stub it linked no Audience Network SDK,
  and `doc/setup/facebook.md` explains the bidding-only status and the mediation route.
- **Network specifics implemented:**
    - MAX: rewarded ad singleton per unit, revenue callback = impression, privacy before init,
      refuses COPPA.
    - InMobi: numeric placements, reward from the rewards map, Activity-context requirement.
    - LevelPlay: ads only after init, late reward accepted.
    - Unity: 4.19+ instance APIs only, reward amount from `extras`.
    - Start.io: `requiresAdUnitId = false`, ad tag, splash and return ads disabled.
- **Example:**
    - Depends on all seven adapters, so one APK build compiles every adapter.
    - New `integration_test/network_smoke_test.dart` takes credentials through `--dart-define` only.
- **Tooling:** scaffolding / Dart generators in the session scratchpad (not committed); SDK_STATUS
  §3.6; TEMPLATE.md and
  ARCHITECTURE §5 updated for the base class.

**Verified**

- `melos run analyze`: no issues in all packages. `melos run test`: **159 Dart tests** pass (core
  68, platform interface 22,
  AdMob 20, five adapters × 9, Facebook stub 2, example 2).
- **Every Android adapter compiles against its real pinned SDK** (`gradlew compileDebugKotlin`).
  Kotlin `Errors` tests pass for all six
  native adapters. `flutter build apk --debug` succeeds with all seven adapters.
    - The compiler forced two fixes: the `MaxAdViewConfiguration` package, and Unity's privacy APIs
      being Kotlin properties. Both are
      recorded in SDK_STATUS §3.6.
- **Opt-in linking: the exact CLAUDE.md scenario** (a scratch app outside the workspace with only
  `unified_ads` + `admob` + `unity`
    + `inmobi`):

    - `releaseRuntimeClasspath` contains only `play-services-ads(-api,-identifier)`,
      `user-messaging-platform`, `unity-ads` and
      `inmobi-ads-kotlin`.
    - In the built APK, `apkanalyzer dex packages` shows **0 defined classes** for `com.applovin`
      and `com.ironsource` (a few
      *references* from inside the Unity/InMobi SDKs' optional integrations only) and **no**
      `com.unity3d.mediation`,
      `com.startapp` or `com.facebook.ads` at all.

**Device smoke tests (2026-10-07, physical CPH1931 / Android 10, public test credentials per owner
instruction)**

Each run used `example/integration_test/network_smoke_test.dart` (soft per-step checks), with
credentials passed **only** via `--dart-define`.

| Network         | Credentials (public)                           | init | banner           | rewarded load    | interstitial load | interstitial show |
|-----------------|------------------------------------------------|------|------------------|------------------|-------------------|-------------------|
| AdMob (Phase 3) | Google demo ad units                           | ✅    | ✅                | ✅                | ✅                 | ✅                 |
| Start.io        | demo App ID `205489527`                        | ✅    | ✅ (+ impression) | ✅                | ✅                 | ✅ (+ impression)  |
| Unity Ads       | sample Game ID `14851`                         | ✅    | ✅ (+ impression) | ✅                | ✅ ¹               | ✅ (+ impression)  |
| LevelPlay       | official demo app key `25b63cf85` + demo units | ✅    | ⛔ no fill (1044) | ⛔ no fill (1024) | ⛔ no fill (1035)  | —                 |
| InMobi          | official sample account + placements           | ✅    | ⛔ NO_FILL        | ⛔ NO_FILL        | ⛔ NO_FILL         | —                 |
| AppLovin MAX    | none public, so a dummy key (negative test)    | ✅ ²  | ⏱ timeout        | ⏱ timeout        | ⏱ timeout         | —                 |

¹ Sample game 14851 has no interstitial placement (`video` / `Interstitial_Android` →
`invalidConfig` 52102, mapped
correctly), so the interstitial step used its existing full-screen placement `rewardedVideo`.
² With an invalid SDK key MAX still reports init success, then never calls the load callbacks. The
core's load and banner
timeouts turned this into `AdErrorCode.timeout` with no crash or hang. This is documented in
`doc/setup/applovin.md`.

What the results mean:

- **Full end-to-end serving verified on a device: AdMob, Start.io, Unity Ads** (Kotlin native path,
  PlatformView banner,
  events, show).
- **LevelPlay and InMobi:** the native SDKs initialized and the requests round-tripped to the
  networks' servers, which returned
  their own no-fill. That is expected for demo credentials that are bound to the vendors' demo
  package names. The errors were mapped
  correctly (`noFill` + native code). Real fill needs the owner's own app keys / placements (with
  InMobi dashboard test mode).
- **Bug found and fixed:** the LevelPlay banner no-fill code **1044** was mapped to `internal`. It
  is now `noFill` on Android and iOS,
  with a Kotlin test.

**Rename (2026-10-07, owner instruction):** Meta Audience Network is identified by its original
name, **Facebook
Audience Network**: `AdNetwork.meta` → `AdNetwork.facebook`, `unified_ads_meta` →
`unified_ads_facebook`, `MetaAdapter` →
`FacebookAdapter`, JSON `"meta"` → `"facebook"` (`"meta"` is no longer accepted). It is still a
documented stub. Migration note:
`doc/migration/1.0.0-meta-to-facebook.md`. All analysis and tests are green after the rename.

**Facebook adapter upgrade (2026-10-07, owner instruction: "analyze facebook_audience_network and
write this code under
unified_ads_facebook"; reverses A10's stub):**

- **Analysis:**
    - The pub.dev plugin `facebook_audience_network` (v1.0.1, MIT, abandoned Dec 2021) has floating
      `6.+` SDKs, no AGP 8
      namespace, and no iOS init / test devices / rewarded. Its banner never calls `destroy()`.
    - It was used as a reference for the SDK call shapes only; **no code was copied**.
    - API names come from the 6.22.0 AAR (`javap`, compiler) and the FBAudienceNetwork 6.22.0
      headers, cross-checked
      against Google's Meta mediation adapters.
- **Built from the Phase 4 template:**
    - Pigeon schema; Dart `FacebookAdapter extends BridgedAdNetworkAdapter` (
      `TestModeSupport.testDevices`, default reward
      from `extras`).
    - Kotlin: `buildInitSettings().withInitListener` init, `InterstitialAd` / `RewardedVideoAd` with
      `buildLoadAdConfig`,
      an `AdView` banner that always calls `destroy()`, LDU / mixed-audience consent, and `Errors` +
      a JUnit test.
    - Swift: equivalent `FBAudienceNetworkAds` / `FBInterstitialAd` / `FBRewardedVideoAd` /
      `FBAdView` code with the ordered
      event queue.
    - Packaging: podspec (iOS 15, `FBAudienceNetwork` 6.22.0) + `Package.swift`.
- **Cleartext:** the example app gained `res/xml/network_security_config.xml`, which allows
  cleartext for **127.0.0.1 only**.
  Without it the device returned AdError 7003. This is documented as an app-level step (a library
  can't safely ship one).
- **Verified:**
    - melos format / analyze / test are green, and the Facebook adapter has 9 Dart tests (was 2 stub
      tests).
    - `:unified_ads_facebook:testDebugUnitTest`: 3 Kotlin tests pass. The example APK builds with
      all seven adapters.
    - Opt-in re-check: the subset app (AdMob + Unity + InMobi) release APK still has **0**
      `com.facebook.ads` classes.
- **Device smoke test (CPH1931)** with the `IMG_16_9_APP_INSTALL#` test placements from the
  reference plugin's example:

  | init | banner | interstitial load | interstitial show | rewarded load |
    |---|---|---|---|---|
  | ✅ | ✅ (+ impression) | ✅ | ✅ | ⛔ 1203 |

  There is no public rewarded placement; a non-rewarded placement returns 1203 (display format
  mismatch).
    - Bug found and fixed: 1203 / 1011 were mapped to `internal`. They are now `invalidConfig` on
      Android and iOS, with a
      Kotlin test.
    - Rewarded serving still needs an owner-created rewarded-video placement.

**Versioning (2026-10-08, owner instruction):** the initial version of all nine packages is **1.0.0
** (was 0.0.1): pubspecs,
inter-package constraints (`^1.0.0`), podspecs, CHANGELOG headings and install snippets. The
migration note was renamed to
`doc/migration/1.0.0-meta-to-facebook.md`. Nothing had been published, so no migration is needed.

**Pending**

- Serving tests for LevelPlay, InMobi and AppLovin MAX with the owner's own credentials (same
  command, owner's IDs).
- **iOS for all adapters:** written against binary-verified names where available, not yet
  compiled (Phase 6 CI). The
  remaining ⚠ Swift spellings are listed per setup doc.

### Phase 5: Example App (Deliverable 6a)

- Settings screen: checkboxes per network, text fields for App ID plus per-format unit IDs,
  test-mode toggles (global and per network), and waterfall reordering.
- Persistence with `shared_preferences`; Save → `UnifiedAds.dispose()` + `init()`.
- Demo screen: load/show buttons for banner, interstitial, and rewarded; a banner network selector (
  force a network); `servedBy` display.
- Live event log console with timestamps (filterable, clearable).
- Test IDs live only here.

Exit: the app runs on both platforms. Every event type is visible in the log.

#### Phase 5 progress log (2026-10-08)

**Delivered** (owner request: "all ad options initialized, a button per network, ads shown on that
screen")

- **`example/lib/main.dart`:** `DemoApp` → `HomeShell` with **Ads · Settings · Log** tabs (an
  `IndexedStack` keeps loaded
  ads alive across tabs). `admobTestConfig` is kept for `plugin_integration_test.dart`.
- **`lib/src/ads_screen.dart`:**
    - **Status header:** one chip per network (ready / failed / skipped / pending), Re-initialize,
      and a banner size selector.
    - **"Waterfall (auto)" card:** shows `servedBy` for each ad.
    - **`AdTestCard` per network:** uses `forceNetwork` and has buttons **Banner** (rendered inline
      in the card),
      **Load / Show interstitial** and **Load / Show rewarded**.
    - Each card shows a status line per format (`ready (served by X)`, `showing`, `closed`,
      `reward earned`, or
      `code [native code]`). Buttons are disabled with the reason while a network isn't ready.
- **`lib/src/ads_controller.dart`:**
    - flow: ATT → UMP consent (only if AdMob is enabled) → `UnifiedAds.init`;
    - per-network status comes from `InitResult.ready` / `failed` / `skipped`;
    - Save → re-init (`init` disposes the previous session); a `generation` counter recreates the
      cards' ad objects.
- **`lib/src/settings_screen.dart`:**
    - global test mode and a reorderable waterfall;
    - per network: enable checkbox, test mode (Global / On / Off), App ID (labelled per network),
      banner / interstitial /
      rewarded IDs, and test device IDs;
    - **Save & re-initialize** and **Reset to public test IDs**.
- **`lib/src/settings_store.dart`:** `shared_preferences` persistence using the existing
  `AdConfigLoader.toJson` / `fromJson`
  (same schema as `ads_config.json`). A corrupt value falls back to the defaults.
- **`lib/src/event_log.dart` + `log_screen.dart`:** every `UnifiedAds.events` kind plus the app's
  steps, with `HH:mm:ss.SSS`
  timestamps. Filter by network or errors only, clear, and a tab badge.
- **`lib/src/test_credentials.dart`:** public test IDs only, already documented in
  `doc/getting_ids.md`. MAX and LevelPlay are
  disabled by default: MAX has no public key, and LevelPlay conflicts with Unity (A11).
- **Other changes:**
    - `shared_preferences: ^2.5.5` added to the example;
    - example iOS deployment target 13 → **15** (Facebook adapter);
    - `example/README.md` rewritten as a user guide;
    - root README gained an "Example app" section, a Facebook row in the IDs table, and the iOS 15
      note.

**Verified**

- `flutter analyze` (example) is clean. `flutter test`: **7 tests** pass:
    - 3 widget tests: the cards render, Load before init reports `notInitialized`, and network
      buttons are disabled until ready;
    - 4 settings-store tests: defaults, round trip, reset, and corrupt value.
- **Device (CPH1931 / Android 10):** the new `integration_test/example_app_test.dart` taps through
  the real UI with the default
  test IDs. Init: ready = AdMob, Facebook, Unity, Start.io, InMobi; skipped = MAX, LevelPlay (
  disabled).

  | Card | Banner (inline) | Interstitial load | Interstitial show |
    |---|---|---|---|
  | Facebook | ✅ showing | ✅ ready | (not shown) |
  | Unity Ads | ✅ showing | ✅ ready | (not shown) |
  | Start.io | ✅ showing | ✅ ready | (not shown) |
  | InMobi | ⛔ `noFill [NO_FILL]` | ⛔ `noFill [NO_FILL]` | — |
  | AdMob | ✅ showing | ✅ ready | ✅ showing |

- Test fixes during the run: `scrollUntilVisible` stops while the button is still under the
  navigation bar, so the test
  added `ensureVisible`; the show step now waits for a show result.

**Not yet verified**

- **iOS** (Phase 6 CI).
- Rewarded show through the UI: it uses the same code path as interstitial; rewarded serving was
  verified by the Phase 4
  smoke tests.
- The Settings screen on a device. It is covered by the widget and store tests only.
- Every event kind in the log on a device. The log subscribes to the whole `UnifiedAds.events`
  stream; clicked /
  earnedReward need a manual tap.

### Phase 6: Tests, CI, Docs, pub.dev Readiness (Deliverable 6b)

- `.github/workflows/ci.yaml`: format check, analyze, unit/widget tests,
  `flutter build apk --debug`, `flutter build ios --no-codesign`, plus an **opt-in verification job
  ** that builds the example with a network subset and checks that `./gradlew :app:dependencies` and
  `Podfile.lock` contain no excluded SDKs.
- README with a feature matrix (network × format × platform), CHANGELOG per package, CONTRIBUTING,
  and `doc/single_package_mode.md` (final).
- Run `pana` per package. Fix scoring issues and confirm dartdoc coverage is 100%.

Exit: CI is green, and pana reports the max achievable score per package.

#### Phase 6 progress log (2026-10-08)

Owner decisions:

- The repository is `https://github.com/rsagar024/unified_ads`.
- **No `git init`** (so CI is written but not yet run), and `.gitignore` stays as is.
- The LICENSE holder stays "The unified_ads Authors".
- The pubspec → JSON config CLI is in scope.

**Delivered**

- **`.github/workflows/ci.yaml`**, pinned to Flutter 3.44.6 and JDK 17, with concurrency cancel. Jobs:

  | Job | Runner | Steps |
  |---|---|---|
  | `dart` | ubuntu | melos format → analyze → test, `generate_config --set-exit-if-changed` on the fixture, then a publish dry-run for all 9 packages |
  | `android` | ubuntu | example APK with all 7 adapters, then `tool/kotlin_tests.sh` |
  | `ios` | `macos-26` + latest-stable Xcode | `tool/ios_build.sh` matrix `spm` / `cocoapods-dynamic` / `cocoapods-static` |
  | `opt-in` | ubuntu + macos-26 | `tool/verify_opt_in.sh android` / `ios` |
  | `pana` | ubuntu | `tool/pana.sh` |

- **`tool/` scripts:**
  - `verify_opt_in.sh`:
    - creates a scratch app outside the workspace with hosted-style constraints plus path overrides;
    - checks the resolved `releaseRuntimeClasspath` (Android) or `Podfile.lock` (iOS, CocoaPods mode);
    - verifies every selected SDK is present and every other one absent;
    - `NETWORKS=` picks the subset, and `OPT_IN_LEAK=` is a self-test that must fail.
  - `kotlin_tests.sh`.
  - `ios_build.sh`: generates the Podfile, sets `platform :ios, '15.0'` (Facebook), and applies static linkage
    for that mode.
  - `pana.sh`: copies each package, strips `resolution: workspace`, and overrides siblings by path, since they are
    unpublished.
- **New melos scripts:** `test:kotlin`, `verify:opt-in`, `config:check`, `pana`. melos runs `run:` through cmd on
  Windows, so every multi-step script is a bash file.
- **pub.dev readiness, all 9 packages:**
  - removed `publish_to: none`; added `homepage`, `repository`, `issue_tracker` and `topics`;
  - added an `example/README.md` (pana accepts it; checked against pana 0.23.19's candidate list). Every Dart
    snippet in them compiles (checked in the example app);
  - package READMEs now use absolute links (pub.dev) and current status lines;
  - CHANGELOGs rewritten as 1.0.0 release notes (pinned SDKs, known limitations).
- **Config CLI:**
  - `dart run unified_ads:generate_config` (`bin/` + `lib/src/cli/`, pure Dart, new dependency `yaml`). Options:
    `--pubspec`, `--output`, `--set-exit-if-changed`.
  - The schema now lives in pure-Dart `lib/src/config_schema.dart`. `AdConfigLoader.fromJson` validates with it
    first, so the CLI and the runtime report identical `path: message` errors (a test asserts parity). The
    loader's key sets come from the same constants.
  - CI fixture: `test/fixtures/pubspec_fixture.yaml` → `ads_config.json`.
- **Docs:**
  - new `doc/consent_and_att.md` (provider abstraction, UMP, custom CMP, per-network mapping, ATT);
  - `doc/single_package_mode.md` is now the final design (not shipped; constraints, trade-offs, switching
    modes);
  - README: badges, a feature matrix with package min OS and test-mode columns, the declarative config, the CI
    overview;
  - CONTRIBUTING: a checks table and a Releasing section (publish order);
  - ARCHITECTURE §11: `UmpConsentProvider` → `AdmobConsentProvider` (the real class name).

**Bugs found by the publish dry-run (fixed)**

- **All 7 adapters were unpublishable.** Pigeon-generated `messages.g.dart` imports `package:meta`, which no
  adapter declared. The analyzer missed it because `*.g.dart` is excluded from analysis. Added `meta: ^1.16.0`.
- **Each archive was 13–14 MB.** Per-package `build/` folders (a 45 MB `.dill`) were included, because the root
  `.gitignore` only covers `/build/`. Added a `.pubignore` per package, and the archives are now 20–41 KB.

**Verified (Windows, 2026-10-08)**

- `melos run format`: 0 changed. `analyze`: no issues in all 10 packages. `test`: **180 Dart tests** pass (core 77
  (+9 CLI/schema), platform interface 22, AdMob 20, six adapters × 9, example 7).
- `config:check` is up to date. The CLI runs on the plain Dart VM (`dart run unified_ads:generate_config`).
- `flutter pub publish --dry-run`: **0 warnings** for all 9 packages.
- `flutter build apk --debug` (example). `test:kotlin`: 17 Kotlin tests pass across the 7 adapters.
- `bash tool/verify_opt_in.sh android`: passes, with AdMob/Unity/InMobi present and the other 4 absent.
  With `OPT_IN_LEAK=startapp` it **fails** as intended (`com.startapp:inapp-sdk:5.4.0` reported).

**Not verified (needs the first CI run, after the owner pushes)**

- The workflow itself, in particular the `ios` matrix (the first-ever Swift compile of all adapters) and
  `verify_opt_in.sh ios`. Expect the ⚠ Swift names in `doc/setup/*.md` to surface here.
- ⚠ The `macos-26` runner label and Xcode 26.2+ availability on GitHub-hosted runners.
- **pana scores.** pana cannot run on Windows (its sandbox rejects any path containing `:`), and `dart doc` crashes
  in this Windows SDK install (dartdoc 9.0.4 `RangeError` in an SDK file). Documentation coverage is enforced by
  the `public_member_api_docs` lint (clean). After the first run, record the scores here and set `PANA_MAX_LOST`
  in the `pana` job. Possible pre-publish deductions: dependency checks against unpublished siblings.

### Phase 7: Stretch Goals

**Status (2026-10-08): the owner chose three of the four items:**

- RI + App Open;
- AdMob Android → Next-Gen;
- Meta via mediation.

Single-package mode stays documented only. Constraints set by the owner: **no new packages**, and Meta bidding must
work with SwiftPM as well. That led to the opt-in model: the app adds the vendor's Meta adapter, and our packages
detect it at runtime.

- Rewarded Interstitial and App Open behind the same `AdNetworkAdapter` interface (optional
  capabilities, gated by `supportedFormats`).
- Single-package mode implementation, if you want it shipped rather than just documented.
- **AdMob Android → GMA Next-Gen SDK** (
  `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk`), migrating off the maintenance-mode
  legacy SDK (A9). Behind the same adapter API; a migration note is needed if config changes.
- **Facebook Audience Network demand via mediation:** opt-in Facebook/Meta bidder adapters inside
  `unified_ads_admob` / `unified_ads_applovin` / `unified_ads_ironsource` (A10).

#### Phase 7 progress log (2026-10-08)

**Delivered**

- **Rewarded interstitial + app open:**
  - Core:
    - `RewardedInterstitialAd` (+ `RewardedInterstitialCallback`) and `AppOpenAd`, on the existing `FullScreenAd`. The
      waterfall, cache, preload and frequency caps were already format-generic, so nothing else in core changed.
    - `AppOpenAd`'s dartdoc shows the resume pattern.
  - AdMob: both formats on Android (Next-Gen) and iOS. MAX: app open (`MaxAppOpenAd` / `MAAppOpenAd`); MAX has no RI.
  - Other adapters are unchanged, because `supportedFormats` already excludes these formats.
  - Fixed a latent bug: the AdMob/MAX `nativeLoad` mapped every non-rewarded format to interstitial. It is now an
    exhaustive `switch`.
  - Example:
    - `AdTestCard` builds Load/Show buttons from each adapter's `supportedFormats`;
    - Settings has RI and App Open ID fields, and `toConfig()` no longer drops them;
    - added Google's demo IDs (checked on Google's test-ads pages today).
- **AdMob Android → GMA Next-Gen 1.5.0:**
  - All API names were read from the AAR with `javap` before coding. Init uses `InitializationConfig` (App ID +
    request configuration) on a worker thread. There is no public `RequestConfiguration.toBuilder()`, so the
    configuration is rebuilt from the adapter's state.
  - Requests are `AdRequest.Builder(adUnitId)`. Banners use `AdView.loadAd(BannerAdRequest…)`.
  - **Every callback is posted to the main thread**, because Next-Gen calls back on background threads. Errors map by
    enum (`nativeCode` is the enum name; `TIMEOUT` → `timeout`).
  - Migration note: `doc/migration/1.0.0-admob-next-gen.md`, including the `play-services-ads` exclusion and the
    incompatibility with the `google_mobile_ads` plugin.
- **Meta bidding (opt-in):** new `MetaBidding.kt` / `MetaBidding.swift` in the admob, applovin and ironsource packages.
  - It works by reflection or the ObjC runtime only, so there is no dependency.
  - It detects the vendor adapter class and forwards `ccpaOptOut` (Limited Data Use) and `coppa` (mixed audience) to FAN
    `AdSettings` in `applyConsent`, which core calls before `initialize`. LevelPlay also gets the `Meta_Mixed_Audience`
    metadata.
  - Pigeon `initialize` now returns `InitInfo(metaBiddingAdapter)`, logged through the new protected
    `BridgedAdNetworkAdapter.logMetaBidding`.
  - The consumer R8 rules keep the adapter names.
  - Every class and selector name was checked in the vendor binaries or headers (SDK_STATUS §1.1).
  - Setup docs have per-build-system snippets.
- **Verification tooling:**
  - `verify_opt_in.sh` now checks for Next-Gen and that the legacy GMA is **absent**.
  - New `META_BIDDING=admob|applovin|ironsource` mode, added to the CI opt-in matrix (Android × 3, plus iOS AdMob).
- **Docs:**
  - `doc/setup/{admob,applovin,ironsource,facebook}.md`, SDK_STATUS (§1 table, §1.1, §2.1);
  - README matrix (RI, App Open and Meta bidding columns);
  - CHANGELOGs and package READMEs.

**Verified (Windows + physical CPH1931 / Android 10)**

- `melos run format` / `analyze` / `test`: **187 Dart tests** pass (core 81, platform interface 22, AdMob 22, six
  adapters × 9, example 8). `config:check` is up to date. The publish dry-run reports 0 warnings for all 9 packages.
- `tool/kotlin_tests.sh`: **27 Kotlin tests** pass, including the Next-Gen `ErrorsTest` and 3 × `MetaBiddingTest` with a
  fake `AdSettings`.
- `verify_opt_in.sh android`:
  - default run: Next-Gen present, legacy absent, FAN absent;
  - `META_BIDDING=admob` / `applovin` / `ironsource`: FAN present and legacy absent.
- **Device, `plugin_integration_test` (AdMob on Next-Gen):**
  - banner rendered;
  - rewarded, **rewarded interstitial** and **app open** test ads loaded;
  - interstitial loaded **and shown**;
  - the log says "Meta bidding adapter not present".
- **Device, `example_app_test` (full UI):** the same results as Phase 5. AdMob, Facebook, Unity and Start.io serve, and
  InMobi returns NO_FILL.
- **Device, Meta detection:** a scratch app with AdMob + `com.google.ads.mediation:facebook:6.22.0.1` and the
  documented exclusion **built** (no duplicate classes with Next-Gen). On the phone it logged `Meta bidding adapter
  detected (com.google.ads.mediation.facebook.FacebookMediationAdapter)`, and AdMob initialized and loaded an
  interstitial.

**Not verified**

- **iOS:** every Swift change (RI, App Open, MAX app open, `MetaBidding.swift`) is checked against headers but compiles
  first in CI.
- **Showing RI or app open through to reward/close** needs a person on the device. Both formats load on the device, and
  the reward path is covered by unit tests.
- **MAX app open serving:** needs the owner's SDK key.
- **Real Meta fill through any mediation platform:** needs owner dashboard setup (bidding enabled in AdMob, MAX or
  LevelPlay, plus Monetization Manager).

---

## 6. Phase 1: Detailed Checklist

### 6.1 SDK research (output: `SDK_STATUS.md`)

For **each** of the 7 networks, record with source links and a "verified on" date:

- [x] Latest stable **Android** SDK version + Maven coordinates
- [x] Latest stable **iOS** SDK version + CocoaPods name, and whether SwiftPM is supported
- [x] Minimum Android API level and minimum iOS version
- [x] Native support for Banner / Interstitial / Rewarded (and Rewarded Interstitial / App Open)
- [x] Initialization API and required credentials (App ID, Game ID, SDK key, App Key, Account ID, …)
- [x] Test-mode mechanism (test device IDs, test flag, test placements)
- [x] Required AndroidManifest entries and Info.plist keys
- [x] SKAdNetwork ID list source
- [x] Privacy APIs: GDPR, CCPA, COPPA flags and how consent is passed in
- [x] Bundled R8/ProGuard rules (or which rules we must ship)
- [x] Static vs dynamic framework constraints and `use_frameworks!` compatibility
- [x] Status changes: deprecation, merger, or rename

Known items to verify explicitly (not assumed true):

- [x] Unity Ads vs ironSource → **Unity LevelPlay**: do they remain separate SDKs, and which APIs
  are current?
- [x] **Meta Audience Network**: current status, bidding-only requirements, and whether standalone
  waterfall usage is still supported
- [x] **StartApp → Start.io** rebranding: current artifact names
- [x] **InMobi**: whether the Account ID + Placement ID model is still current
- [x] **AppLovin MAX**: the current initialization API (SDK key vs init configuration)

Per network, decide: **Full adapter / Partial adapter / Documented stub**, with a reason.

### 6.2 Architecture (output: `ARCHITECTURE.md`)

- [x] Mermaid component diagram: app → `unified_ads` → `platform_interface` ← adapters → native SDKs
- [x] Package dependency graph that shows **core never depends on any adapter**
- [x] `AdNetworkAdapter` contract: method signatures, event semantics, threading guarantees, error
  contract
- [x] Adapter registration flow (`dartPluginClass` / `registerWith` → `AdapterRegistry`)
- [x] **Opt-in linking on Android**: SDK `implementation` lives only in the adapter's
  `build.gradle.kts`, so an unused adapter means no Gradle module and no SDK in the APK
- [x] **Opt-in linking on iOS**: SDK dependencies live only in the adapter's podspec /
  `Package.swift`, so an unused adapter means no pod, no linker input, and no warnings
- [x] Waterfall, cache/preload, and frequency-cap sequence diagrams
- [x] Banner PlatformView design: sizing negotiation, safe area, gesture handling, Hybrid
  Composition vs Texture Layer choice
- [x] Lifecycle: Activity/ViewController attach/detach, pause/resume, rotation, hot restart
- [x] Threading: main-thread rules, and how Pigeon callbacks are marshalled
- [x] Error model: native error → `AdError` code table
- [x] Consent + ATT abstraction
- [x] Logging design (`AdsLogger`)
- [x] **Alternative single-package mode**: `--dart-define=ADS_NETWORKS=...`, Gradle
  properties/flavors that add dependencies conditionally, Podfile `ENV` conditionals, plus a
  trade-offs table (simplicity vs. tree-shaking risk, harder versioning, and dart-define plus native
  flags having to stay in sync)

### 6.3 Review gate

- [x] You review `SDK_STATUS.md` and the stub decisions
- [x] You review `ARCHITECTURE.md` and the adapter contract
- [x] Open decisions A1–A11 confirmed or changed

*Gate passed 2026-10-07: the owner instructed "start phase 2" after receiving the Phase 1
documents.*

---

## 7. Risk Register

| Risk                                                                          | Impact                                                                         | Mitigation                                                                                |
|-------------------------------------------------------------------------------|--------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Rapid SDK churn / breaking API changes                                        | Adapter breakage                                                               | Pin versions per adapter, date-stamp `SDK_STATUS.md`, keep adapters thin                  |
| Facebook Audience Network restrictions (bidding / mediation-only)             | Direct adapter serves test ads only                                            | Full adapter with prominent docs (A10, owner reversal); mediation path in Phase 7         |
| Unity Ads + LevelPlay in one app                                              | No duplicate symbols (shared artifact), but "whichever initializes first wins" | **Decided: runtime-exclusive guard** (A11) + docs                                         |
| AdMob Android legacy SDK in maintenance mode                                  | No new features; eventual deprecation                                          | ✅ Resolved in Phase 7: Android on Next-Gen 1.5.0 (A9); apps must keep legacy `play-services-ads` out |
| Unity Ads static API removed in 5.0                                           | Adapter breaks on upgrade                                                      | Adapter built only on 4.19+ instance APIs                                                 |
| Facebook Audience Network CocoaPods distribution reportedly ends after 6.22 ⚠ | Later FAN versions can't use CocoaPods                                         | Adapter ships a podspec (6.22.0) **and** `Package.swift`; go SPM-only on the next upgrade |
| Xcode floor (AdMob iOS 13.4+ says Xcode 26.2 ⚠)                               | CI iOS build fails on older runners                                            | CI uses `macos-26` + latest-stable Xcode (⚠ label unverified until the first run)         |
| Test mode not enforceable for InMobi / LevelPlay                              | Real ads during development → policy risk                                      | `testModeSupport` capability, an init-time warning, and setup docs                        |
| iOS static vs dynamic framework conflicts                                     | Link errors under `use_frameworks!`                                            | Per-adapter notes, and a CI matrix with and without `use_frameworks! :linkage => :static` |
| PlatformView perf / touch issues                                              | Jank, clicks lost                                                              | Benchmark Hybrid Composition vs TLHC in Phase 3 and document the choice                   |
| Toolchain drift (AGP 9, Kotlin 2.3, Dart 3.12) vs SDK requirements            | Build failures                                                                 | Phase 1 records each SDK's Gradle/Kotlin constraints                                      |
| Store policy (ATT, UMP, SKAdNetwork)                                          | App rejection                                                                  | Setup docs + example app wiring                                                           |

---

## 8. Definition of Done (per phase)

| Phase | Done when                                                                                                                                                                                                                         |
|-------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0     | Workspace resolves; analyze passes; identifiers renamed *(✅ 2026-10-07; git init deferred)*                                                                                                                                       |
| 1     | `ARCHITECTURE.md` + `SDK_STATUS.md` reviewed; A1–A11 settled *(docs delivered 2026-10-07; review pending)*                                                                                                                        |
| 2     | Public API is complete with dartdoc; unit/widget tests green; API reviewed *(✅ 2026-10-07; owner proceeded to Phase 3)*                                                                                                           |
| 3     | AdMob test ads work on both platforms; subset exclusion verified; template documented *(Android ✅ on device, exclusion ✅, template ✅; iOS pending CI)*                                                                            |
| 4     | All 7 adapters implemented or stubbed with docs; smoke-tested *(✅ 2026-10-07: device serving verified for AdMob, Start.io, Unity; LevelPlay and InMobi round-trip to no-fill on demo creds; MAX needs owner key; iOS pending CI)* |
| 5     | Example app meets all CLAUDE.md example requirements                                                                                                                                                                              |
| 6     | CI green (Android + iOS builds + opt-in check); pana clean; README matrix complete *(2026-10-08: delivered; every local check green; the CI run, iOS and pana await the first push)*                                             |
| 7     | Stretch formats behind the same interface, with migration notes if the API changed *(2026-10-08: RI + App Open, Next-Gen and Meta bidding delivered; Android verified on device; iOS pending CI)*                                 |
