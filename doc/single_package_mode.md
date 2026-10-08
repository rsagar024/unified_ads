# Single-package mode (alternative)

> Status: **final design, not shipped** (reviewed in Phase 6, 2026-10-08). The supported mode is the federated one in
> [`ARCHITECTURE.md`](../ARCHITECTURE.md) §4: one package per network, verified in CI by
> [`tool/verify_opt_in.sh`](../tool/verify_opt_in.sh). This document is the complete design for teams that want a
> single dependency. Building it is an optional Phase 7 item, and it would ship as an extra package (`unified_ads_all`)
> next to the federated ones, not instead of them.

## Idea
Ship one package, `unified_ads_all`, containing every adapter's Dart, Kotlin and Swift code. The app selects networks
with **three flags that must agree**:

| Layer | Flag | Effect |
|---|---|---|
| Dart | `--dart-define=ADS_NETWORKS=admob,unity,inmobi` | Only the listed adapters are registered, and the others are tree-shaken |
| Android | `unifiedAds.networks=admob,unity,inmobi` in `android/gradle.properties` | Only the listed source sets and `implementation(...)` SDK deps are compiled |
| iOS | `ENV['UNIFIED_ADS_NETWORKS'] = 'admob,unity,inmobi'` at the top of `ios/Podfile` | Only the listed `source_files` and `s.dependency` entries are used |

## Mechanics

### Dart
`String.fromEnvironment('ADS_NETWORKS')` is a compile-time constant, but `.split(',').contains('admob')` is
**not** const-evaluated, so a check written that way would keep every adapter in the binary. The design therefore
uses one boolean define per network, which the compiler folds, so dead branches (and their adapters) are tree-shaken:

```dart
const _admob = bool.fromEnvironment('ADS_ADMOB');
const _unity = bool.fromEnvironment('ADS_UNITY');
// …

void registerSelectedAdapters() {
  if (_admob) AdapterRegistry.instance.register(AdmobAdapter());
  if (_unity) AdapterRegistry.instance.register(UnityAdapter());
  // …
}
```
The user-facing `--dart-define=ADS_NETWORKS=admob,unity` is expanded into `--dart-define=ADS_ADMOB=true …` by a
`dart run unified_ads_all:flags` helper, which also prints the matching Gradle and Podfile lines so all three layers
stay in sync. ⚠ If it is built, Phase 7 must verify that excluded adapters are tree-shaken (`--analyze-size`).

A Flutter plugin has one `dartPluginClass`, so `unified_ads_all` registers `UnifiedAdsAll.registerWith()`, which
calls `registerSelectedAdapters()`. The per-network adapters move to `lib/src/<network>/` and are no longer
registered by Flutter's plugin registrant.

### Android (`android/build.gradle.kts` of `unified_ads_all`)
```kotlin
val networks = (project.findProperty("unifiedAds.networks") as String? ?: "")
    .split(',').map { it.trim() }.filter { it.isNotEmpty() }.toSet()

android {
    sourceSets["main"].java.srcDirs(networks.map { "src/$it/kotlin" } + "src/main/kotlin")
}
dependencies {
    if ("admob" in networks) implementation("com.google.android.gms:play-services-ads:25.5.0")
    if ("unity" in networks) implementation("com.unity3d.ads:unity-ads:4.21.0")
    // …
}
```
The plugin's `GeneratedPluginRegistrant` entry is a single `UnifiedAdsAllPlugin`, which registers the per-network
native handlers by reflection-free lookup of the classes compiled in (a generated `EnabledNetworks.kt` is written
by a Gradle task from the same property).

### iOS (`unified_ads_all.podspec`)
```ruby
networks = (ENV['UNIFIED_ADS_NETWORKS'] || '').split(',').map(&:strip)
s.source_files = ['Classes/Core/**/*'] + networks.map { |n| "Classes/#{n}/**/*" }
s.dependency 'Google-Mobile-Ads-SDK', '13.11.0' if networks.include?('admob')
s.dependency 'UnityAds', '4.21.0'               if networks.include?('unity')
# Swift conditional compilation for the plugin registrar:
s.pod_target_xcconfig = { 'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => networks.map { |n| "ADS_#{n.upcase}" }.join(' ') }
```

### Constraints that carry over from the federated packages

- **Android:** minSdk 24, AGP 9, Kotlin 2.3. Each network's consumer R8 rules move to `proguard/<network>.pro`, and
  only the selected ones are passed to `consumerProguardFiles`. Facebook's cleartext-to-`127.0.0.1` rule stays an
  app-level step.
- **iOS:** iOS 13, or **15 when `facebook` is selected** (the podspec raises `s.platform` conditionally). Every
  network's SKAdNetwork IDs stay an app `Info.plist` step either way.
- **Unity Ads + LevelPlay** stay runtime-exclusive (A11). The flags helper rejects selecting both.
- **Verification:** the same `tool/verify_opt_in.sh` checks apply. Only the scratch app's dependency block changes,
  to one package plus the three flags.

## Trade-offs

| | Federated (recommended) | Single package |
|---|---|---|
| Dependency lines in pubspec | one per network | one |
| Selecting networks | add or remove a package | three flags (Dart, Gradle, Podfile) that **must match** |
| Misconfiguration | impossible: the package is either there or not | flags drift, so you get a runtime `adapterMissing` or a native "class not found" |
| SwiftPM | supported where the vendor ships SPM | **CocoaPods only** (SPM manifests can't read ENV) |
| Versioning | each adapter versioned and released independently | one version bumps for any SDK change; consumers update all networks together |
| CI / caching | small, focused builds | every build must specify flags; harder to cache |
| Tree-shaking risk | none (code absent) | relies on const-evaluation (Dart) and source-set filtering (native) being correct |
| Hot reload of the network set | needs `pub get` + rebuild | needs a full native rebuild (Gradle/Pod re-sync) |
| pub.dev score / discoverability | per-network packages are discoverable | one package; harder to document per-network setup |

**Recommendation:** use federated mode. Single-package mode is offered only for teams with tooling that already
centralises build flags (e.g. flavor-based monorepos).

## Moving between modes

The public Dart API (`unified_ads`) is the same in both modes, so app code doesn't change. Switching means:

1. Replace the adapter dependencies with `unified_ads_all`, or the reverse.
2. Add or remove the three flags.
3. Do a clean native rebuild (`flutter clean`, then `pod install`).
