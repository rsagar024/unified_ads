# Contributing to unified_ads

Thanks for helping! This repository is a Dart **pub workspace**. It contains a core
package, a platform interface, and one federated adapter package per ad network.
See `ARCHITECTURE.md` for the design and `IMPLEMENTATION.md` for the roadmap.

## Prerequisites

- Flutter stable (3.44+) / Dart 3.12+
- Android Studio + JDK 17 (Android builds)
- Xcode 26.2+ + CocoaPods (iOS builds, macOS only)
- bash (Git Bash on Windows) for the scripts in `tool/`

## Setup

```sh
flutter pub get          # resolves the whole workspace (one lockfile at the root)
dart run melos run analyze
dart run melos run test
```

`melos` is a dev dependency of the workspace root, so it doesn't need a global install.

## Repository layout

| Path | Purpose |
|---|---|
| `packages/unified_ads` | Core public API (what app developers import) |
| `packages/unified_ads_platform_interface` | `AdNetworkAdapter` contract + shared models |
| `packages/unified_ads_<network>` | One adapter per ad network, with native Kotlin/Swift code |
| `example/` | Demo app + integration tests (the only place test ad-unit IDs may appear) |
| `doc/` | Per-network setup guides, consent/ATT, single-package mode |
| `tool/` | CI scripts: opt-in verification, Kotlin tests, iOS build modes, pana |
| `.github/workflows/ci.yaml` | The CI pipeline |

## Rules

1. **Core must never depend on an adapter.** Adapters depend on the platform interface only.
2. **A native SDK dependency lives only in its adapter's** `build.gradle.kts` / podspec / `Package.swift`.
3. **No real ad-unit or app IDs** in any package. Test IDs belong in `example/` only.
4. **Never crash the host app.** Map every native exception to `AdError`.
5. **Document every public symbol** (`public_member_api_docs` is enabled).
6. **Breaking public API changes** need a migration note in `doc/migration/` and a CHANGELOG entry.
7. Don't invent SDK API names. Verify them against `SDK_STATUS.md` and the vendor docs, and
   flag anything unverified in the PR description.

## Adding a new network adapter

Follow the `TEMPLATE.md` checklist in `packages/unified_ads_admob`. Then add the network to:

- the `case` lists in `tool/verify_opt_in.sh`;
- `tool/kotlin_tests.sh` and the `test:kotlin` melos script;
- the README feature matrix.

## Checks (local and CI)

| Command | What it checks | CI job |
|---|---|---|
| `dart run melos run format` | `dart format --set-exit-if-changed` | `dart` |
| `dart run melos run analyze` | `flutter analyze --fatal-infos` in every package | `dart` |
| `dart run melos run test` | Dart unit + widget tests | `dart` |
| `dart run melos run config:check` | the `generate_config` fixture is up to date | `dart` |
| `flutter pub publish --dry-run` (in each package) | pub validation, archive contents (`.pubignore`) | `dart` |
| `dart run melos run build:example` | the example APK with all 7 adapters | `android` |
| `dart run melos run test:kotlin` | each adapter's Kotlin `ErrorsTest` (after `build:example`) | `android` |
| `bash tool/ios_build.sh <mode>` | `flutter build ios --no-codesign` with `spm`, `cocoapods-dynamic` or `cocoapods-static` (macOS) | `ios` |
| `dart run melos run verify:opt-in` | an app with AdMob + Unity + InMobi resolves only those SDKs (`tool/verify_opt_in.sh android`; `ios` on macOS) | `opt-in` |
| `dart run melos run pana` | pub.dev score per package (Linux/macOS only: pana's sandbox rejects Windows paths) | `pana` |

Notes for the scripts in `tool/`:

- `verify_opt_in.sh` takes `NETWORKS=a,b,c` for another subset. `OPT_IN_LEAK=<network>` is a self-test: it adds an
  unselected adapter, and the check must then fail.
- On Windows, Gradle needs `JAVA_HOME` set to the JDK root (for example
  `C:\Program Files\Android\Android Studio\jbr`), not its `bin` folder.

## Releasing

Packages are published separately, in dependency order. Every package must pass `flutter pub publish --dry-run` with 0
warnings first.

1. Bump `version` in each package that changed, and update its `CHANGELOG.md`. If a sibling now needs a newer
   version, update the inter-package constraints (for example `unified_ads_platform_interface: ^1.1.0`).
2. Publish `unified_ads_platform_interface`.
3. Publish `unified_ads`.
4. Publish the adapters (any order).
5. Tag the release as `<package>-v<version>` for each published package.

A breaking change to the public API needs a note in `doc/migration/` (CLAUDE.md non-negotiable).

## Pull requests

- Run `dart run melos run format`, `analyze`, and `test` before you push. CI runs everything in the table above.
- Add a CHANGELOG entry to each package you touch.
- Keep PRs focused. Cover one adapter or one feature per PR.
