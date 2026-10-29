# Publishing to pub.dev

How to release all 9 packages together. pub.dev has no atomic multi-package publish, so "together" means one merge
(automated) or one command (manual) that publishes them **in dependency order**:

```
unified_ads_platform_interface → unified_ads → the 7 adapters
```

Every adapter depends on `^<version>` of the first two, so those must be live on pub.dev first. The order is defined
once in [`tool/lib/packages.sh`](../tool/lib/packages.sh).

## 1. Pre-flight (both paths)

1. Each package being released has its new `version` in its `pubspec.yaml` and a matching `CHANGELOG.md` entry.
2. Inter-package constraints match (for example `unified_ads_platform_interface: ^1.1.0`).
3. From the repository root:

   ```sh
   flutter pub get
   dart run melos run format
   dart run melos run analyze
   dart run melos run test
   ```

4. Dry-run every package. Each one must report **0 warnings**:

   ```sh
   .\tool\publish.ps1          # PowerShell
   bash tool/publish.sh        # Git Bash / macOS / Linux
   ```

5. Optional, Linux/macOS only: `bash tool/pana.sh` to check pub points.

## 2a. Automated release (recommended)

### One-time setup

Done once per repository. See [CONTRIBUTING.md](../CONTRIBUTING.md#branches-and-releases) for details.

- GitHub secret `RELEASE_TAG_TOKEN`: a fine-grained PAT scoped to this repository, **Contents: Read and write**.
- On pub.dev, for **each** of the 9 packages: **Admin → Automated publishing → Enable publishing from GitHub Actions**,
  repository `rsagar024/unified_ads`, tag pattern `<package>-v{{version}}` (for example `unified_ads_admob-v{{version}}`).

### Release

1. Open a PR from your release branch to `development` and merge it. CI and the iOS workflow run only on `master`, so
   first run the local checks (`dart run melos run format`, `analyze`, `test`, and `flutter pub publish --dry-run` in
   each package), or start both workflows by hand on your branch (Actions → Run workflow).
2. Open a PR from `development` to `master` and merge it.
3. When CI and iOS both pass on `master`, `release.yml` runs [`tool/release_tags.sh`](../tool/release_tags.sh). For each
   package whose version is not on pub.dev yet, in order, it pushes the tag `<package>-v<version>` and **waits until
   pub.dev lists that version** before it tags the next package.
4. Each tag runs `publish.yml`. It checks that the tag matches the pubspec and is on `master`, then publishes with
   GitHub OIDC. No pub.dev credential is stored.

Preview what will be tagged at any time:

```sh
bash tool/release_tags.sh --dry-run
```

If a publish fails, fix the problem and re-run the **Release** workflow. Packages already on pub.dev are skipped.

## 2b. Manual release

You must use this path for a brand-new package: pub.dev only allows automated publishing for packages that already
exist.

1. `dart pub login` with a Google account that is an uploader (or verified-publisher admin) for every package.
2. `.\tool\publish.ps1 -Publish` (or `bash tool/publish.sh --publish`). Confirm each package with `y`. It stops at the
   first failure.
3. If an adapter can't resolve the core version it needs right after the core was published, wait a minute or two for
   pub.dev to index it. Then publish the remaining packages one by one: `cd packages/<name>` and run
   `flutter pub publish`. Re-running the script fails on packages that are already published.
4. Tag the release so the automated path stays consistent: `git tag -a <package>-v<version> -m "<package> <version>"`
   for each package, then push the tags.

## 3. After publishing

- Check that each package page shows the new version, its pub points, and both Android and iOS.
- A published version can't be deleted. Within 7 days you can **retract** it (Admin → Versions). Otherwise publish a
  fixed patch version.
