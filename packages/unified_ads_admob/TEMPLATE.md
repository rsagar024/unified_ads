# Creating a new adapter from `unified_ads_admob`

`unified_ads_admob` is the reference adapter. Copy its structure for every other network.

## 1. Verify first
- [ ] Re-verify SDK versions and **every API name** against the vendor's official docs. Record them in `SDK_STATUS.md`
      and mark anything unconfirmed with ⚠. Never invent API names.
- [ ] Decide the formats, `TestModeSupport`, and `requiresAdUnitId` (false when the network has only an app ID, like Start.io).

## 2. Package skeleton (`packages/unified_ads_<network>/`)
- [ ] `pubspec.yaml`: depend on `unified_ads_platform_interface` (runtime) and `unified_ads` (**dev only**), plus `pigeon` (dev).
      `flutter.plugin.platforms` declares android `package` / `pluginClass` / `dartPluginClass` and ios `pluginClass` /
      `dartPluginClass`. **Do not** add `implements:`, because Flutter allows only one implementation per federated plugin.
- [ ] `pigeons/messages.dart`: copy the AdMob schema and drop the consent methods unless the network has a CMP. Keep
      `AdEventMessage` / `AdEventKind` identical so the Dart translation code can be reused.
- [ ] `dart run pigeon --input pigeons/messages.dart`, or `dart run melos run pigeon`.

## 3. Dart adapter (`lib/src/<network>_adapter.dart`)
- [ ] **Extend `BridgedAdNetworkAdapter`** (platform interface). It implements the contract (never throwing, error mapping,
      loaded-ad tracking, the event stream), so the adapter only bridges `nativeInitialize/Load/Show/Destroy/ApplyConsent/Dispose`,
      calls `{Network}EventsApi.setUp(this)` in `listenToNativeEvents`, and forwards `onAdEvent` to `emitNativeEvent`.
      The Phase 4 adapters were generated from one template; `unified_ads_applovin/lib/src/applovin_adapter.dart` is a good model.
- [ ] `class <Network>Adapter extends BridgedAdNetworkAdapter implements <Network>EventsApi` with `static void registerWith()`
      and an injectable host API.
- [ ] (Provided by the base class: never throwing, `PlatformException` → `AdError` with `nativeCode`, `unsupportedFormat`
      without a native call, a synchronous `isReady`, and lazy event registration.)
- [ ] The banner view type is `dev.arovyx.plugin.unifiedads/<network>/banner`. Creation params are `{adId, adUnitId, size, testMode}`.

## 4. Android (`android/`)
- [ ] `build.gradle.kts`: namespace `dev.arovyx.plugin.unifiedads.<network>`, minSdk ≥ 24, and the SDK
      `implementation(...)` **only here**. Add `kotlinx-coroutines-android` (Pigeon suspend APIs) and `consumerProguardFiles`.
- [ ] `consumer-rules.pro`: the vendor's required rules (if the AAR doesn't bundle them) plus a keep rule for the plugin class.
- [ ] Plugin = `FlutterPlugin + ActivityAware + <Network>HostApi`. Use a weak Activity reference, register the banner
      factory, and clear all ads on engine detach.
- [ ] Bridge SDK callbacks with `suspendCancellableCoroutine`, and post events to Dart from the main thread.
- [ ] Put the error mapping in a pure `Errors` object, unit-tested in `src/test/kotlin`.

## 5. iOS (`ios/`)
- [ ] Podspec with `s.dependency '<SDK pod>', '<exact version>'` **only here**, plus `static_framework` if the SDK is
      static, `platform :ios, '13.0'`, and the privacy-manifest bundle.
- [ ] `Package.swift` only if the vendor ships SPM. Otherwise the adapter is CocoaPods-only; document that.
- [ ] Each Pigeon `async` host method delegates to a `@MainActor` implementation. Use the vendor's documented Swift
      API (prefer async forms that are documented).
- [ ] Send events through the ordered queue (`emit`), and find the top view controller from the key window scene.
- [ ] `PrivacyInfo.xcprivacy`: declare any required-reason APIs the adapter itself uses.

## 6. Tests and docs
- [ ] `test/fake_host.dart` + adapter tests: registration, init, load, show, destroy, error mapping, event translation via
      `handlePlatformMessage`, banner params, and unsupported formats.
- [ ] `test/integration_with_core_test.dart`: drive the adapter through `UnifiedAds`.
- [ ] `doc/setup/<network>.md`: manifest / Info.plist, SKAdNetwork source, test mode, privacy, R8, frameworks, and the error table.
- [ ] Add the adapter to `example/` and verify **on a device**. Check that `./gradlew :app:dependencies` and `Podfile.lock`
      contain only the opted-in SDKs.
