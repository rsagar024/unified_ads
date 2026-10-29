# Contributing to unified_ads

Thanks for helping! This repository is a Dart **pub workspace**. It contains a core
package, a platform interface, and one federated adapter package per ad network.
See `ARCHITECTURE.md` for the design and `IMPLEMENTATION.md` for the roadmap.

## Prerequisites

- Flutter stable (3.44+) / Dart 3.12+. CI uses Flutter 3.47.8 (Dart 3.13.7)
- Android Studio + JDK 17 (Android builds)
- Xcode 26.2+ (iOS builds, macOS only). No CocoaPods: since 1.1.0 iOS builds use Swift Package Manager only
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
2. **A native SDK dependency lives only in its adapter's** `build.gradle.kts` / `Package.swift`.
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
| `bash tool/ios_build.sh` | `flutter build ios --no-codesign` with Swift Package Manager (macOS) | `ios` |
| `dart run melos run verify:opt-in` | an app with AdMob + Unity + InMobi resolves only those SDKs (`tool/verify_opt_in.sh android`; `ios` on macOS) | `opt-in` |
| `dart run melos run pana` | pub.dev score per package (Linux/macOS only: pana's sandbox rejects Windows paths) | `pana` |

Notes for the scripts in `tool/`:

- `verify_opt_in.sh` takes `NETWORKS=a,b,c` for another subset. `OPT_IN_LEAK=<network>` is a self-test: it adds an
  unselected adapter, and the check must then fail.
- On Windows, Gradle needs `JAVA_HOME` set to the JDK root (for example
  `C:\Program Files\Android\Android Studio\jbr`), not its `bin` folder.

## Branches and releases

```
feature branch ──PR──▶ development ──PR──▶ master ──(CI ✔ + iOS ✔)──▶ tags ──▶ pub.dev
```

| Event | What runs |
|---|---|
| PR to any branch | Nothing. Run the checks above locally, or start `ci.yaml` / `ios.yml` by hand (Actions → Run workflow) |
| Merge (push) to `development` | Nothing. **Nothing is published.** |
| Merge (push) to `master` | `ci.yaml` + `ios.yml`; when **both** pass, `release.yml` tags and `publish.yml` publishes |

How the automatic release works:

1. `release.yml` runs when CI or the iOS workflow completes for a push to `master`. It continues only when both
   succeeded for that commit.
2. It runs [`tool/release_tags.sh`](tool/release_tags.sh). In dependency order (platform interface → core → adapters,
   [`tool/lib/packages.sh`](tool/lib/packages.sh)), it pushes the tag `<package>-v<version>` for each package whose
   pubspec `version` is **not on pub.dev yet**, then waits until pub.dev lists it before tagging the next package.
   Packages whose version didn't change are skipped.
3. Each tag runs `publish.yml`, which checks that the tag matches the pubspec and is on `master`, then runs
   `flutter pub publish --force` with GitHub OIDC. No pub.dev credential is stored.

pub.dev only accepts automated publishes from **tag** pushes, and tags pushed with the default `GITHUB_TOKEN` don't
trigger workflows. That's why the tags are pushed with a PAT.

### To release

1. In a PR to `development`, for each changed package:
   - bump `version` in its pubspec;
   - add a `CHANGELOG.md` entry;
   - if a sibling now needs a newer version, update the inter-package constraints (for example
     `unified_ads_platform_interface: ^1.1.0`).
2. Every package must pass `flutter pub publish --dry-run` with 0 warnings. CI runs this check on `master`, so run it
   locally (or start CI by hand on your branch) before merging.
3. Merge `development` into `master`. Preview what will be tagged with `bash tool/release_tags.sh --dry-run`.

A breaking change to the public API needs a note in `doc/migration/` (CLAUDE.md non-negotiable).

### One-time setup (repository owner)

1. **GitHub secret `RELEASE_TAG_TOKEN`:**
   - create a fine-grained personal access token under Settings → Developer settings, scoped to this repository only,
     with **Contents: Read and write**;
   - add it under Repository → Settings → Secrets and variables → Actions.
2. **pub.dev, for each of the 9 packages:** package page → **Admin** → **Automated publishing** → *Enable publishing
   from GitHub Actions*:
   - repository: `rsagar024/unified_ads`
   - tag pattern: `<package>-v{{version}}`, for example `unified_ads-v{{version}}` or
     `unified_ads_admob-v{{version}}`
3. **Recommended:** add a tag ruleset (Settings → Rules) for `unified_ads*-v*` that only you (the PAT owner) can
   create. Anyone who can push a matching tag on `master` history can publish.
4. **Optional manual approval:** create a `pub.dev` environment with required reviewers, add `environment: pub.dev`
   to the `publish` job in `publish.yml`, and tick *Require GitHub Actions environment* on pub.dev.

`release.yml` runs from the copy on the default branch, so the flow starts working once these workflows are on
`master`.

Step-by-step guide covering both paths: [doc/publishing.md](doc/publishing.md).

**Manual fallback:** for a brand-new package, run `tool/publish.sh --publish` (or `tool\publish.ps1`). pub.dev only
allows automated publishing for packages that already exist, so the first version has to be published by hand.

## Pull requests

- Run `dart run melos run format`, `analyze`, and `test` before you push. CI runs everything in the table above.
- Add a CHANGELOG entry to each package you touch.
- Keep PRs focused. Cover one adapter or one feature per PR.
