# Publishing to pub.dev

Releases are **manual**. Merging into `master` runs CI and the iOS workflow but never publishes. After a green merge,
the maintainer pulls `master` and publishes from their machine.

pub.dev has no atomic multi-package publish, so all 9 packages are published by one script **in dependency order**:

```
unified_ads_platform_interface → unified_ads → the 7 adapters
```

Every adapter depends on `^<version>` of the first two, so those must be live on pub.dev first. The order is defined
in [`tool/lib/packages.sh`](../tool/lib/packages.sh) (and mirrored in `tool/publish.ps1`).

| Script | Shell |
|---|---|
| `.\tool\publish.ps1` / `.\tool\publish.ps1 -Publish` | PowerShell |
| `bash tool/publish.sh` / `bash tool/publish.sh --publish` | Git Bash, macOS, Linux (not WSL with a Windows SDK) |

Without the flag, the script runs a dry run. With it, the script publishes. In both modes it **skips any package whose
pubspec version is already on pub.dev**, so re-running it is always safe.

## 1. One-time setup

1. Log in to pub.dev with the Google account that is an **uploader** of all 9 packages:

   ```sh
   dart pub login
   ```

   Credentials are stored in `%APPDATA%\dart\pub-credentials.json` (Windows) or `~/.config/dart/pub-credentials.json`.
   `dart pub logout` removes them.
2. On each package's page, open **Admin** → **Uploaders** and check that your account is listed. If you only see the
   public page, you're not an uploader.
3. Leave **Admin → Automated publishing** off. This repository has no publishing workflow.

## 2. Prepare the release (before merging)

On your feature or release branch:

1. For each package you're releasing:
   - bump `version` in its `pubspec.yaml`;
   - add a matching `## <version>` entry at the top of its `CHANGELOG.md`.
2. If an adapter needs a newer core or platform interface, update the inter-package constraints, for example
   `unified_ads_platform_interface: ^1.1.0`.
3. A breaking public API change also needs a note in `doc/migration/`.
4. Run the checks from the repository root:

   ```sh
   flutter pub get
   dart run melos run format
   dart run melos run analyze
   dart run melos run test
   .\tool\publish.ps1            # dry run: every package must report 0 warnings
   ```

5. Optional, Linux/macOS only: `bash tool/pana.sh` to check pub points.
6. Optional: start **CI** and **iOS simulator** on your branch by hand (Actions → choose the workflow → Run workflow).
   They don't run on PRs.

## 3. Merge into master

1. Merge the branch into `development`, then open a PR from `development` to `master` and merge it.
2. Wait until **CI** and **iOS simulator** are both green on the merge commit (Actions tab). Don't publish a red
   commit.

## 4. Publish

```powershell
git checkout master
git pull
flutter pub get
.\tool\publish.ps1            # dry run on exactly what you'll publish
.\tool\publish.ps1 -Publish   # publish
```

In Git Bash: `bash tool/publish.sh`, then `bash tool/publish.sh --publish`.

What `-Publish` / `--publish` does:

1. It refuses to run unless you're on `master`, the working tree is clean, and `master` matches `origin/master`.
2. For each package in order:
   - if its version is already on pub.dev, it prints `already on pub.dev → skip`;
   - otherwise it runs `dart pub publish`, which shows the archive contents and asks **"Do you want to publish …?"**.
     Answer `y`.
3. After `unified_ads_platform_interface` and after `unified_ads`, it waits until pub.dev lists the new version
   (up to 15 minutes; change it with `-WaitSeconds` / `PUBLISH_WAIT_S`). The adapters can only be published after
   that.
4. It stops at the first failure. Fix the problem and run the same command again: packages already published are
   skipped.

## 5. Tag the release (recommended)

Tags record which commit each version came from. They don't trigger anything.

PowerShell:

```powershell
foreach ($p in Get-ChildItem packages -Directory) {
  $v = ((Select-String -Path "$($p.FullName)\pubspec.yaml" -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value).Trim()
  git tag -a "$($p.Name)-v$v" -m "$($p.Name) $v"
}
git push origin --tags
```

Git Bash:

```sh
for d in packages/*/; do
  p=$(basename "$d"); v=$(sed -n 's/^version:[[:space:]]*//p' "$d/pubspec.yaml" | tr -d "\r '\"")
  git tag -a "$p-v$v" -m "$p $v"
done
git push origin --tags
```

`git tag` fails with "already exists" for packages whose version didn't change. That's expected; those tags are
already there.

## 6. After publishing

- Open each package page and check that it shows the new version, its pub points, and both Android and iOS. Scoring
  can take a few minutes.
- A published version can't be deleted. Within 7 days you can **retract** it (Admin → Versions). Otherwise publish a
  fixed patch version.

## Troubleshooting

| Problem | Fix |
|---|---|
| `On 'xyz'. Publish from master` / `not clean` / `differs from origin/master` | `git checkout master`, commit or stash local changes, `git pull` |
| `You don't have permission to upload` / not an uploader | Log in with the right account (`dart pub logout`, `dart pub login`), or have an existing uploader add you under Admin → Uploaders |
| `Version x.y.z of package … already exists` | It's already published. Re-run the script: it now skips that package |
| An adapter fails with "depends on unified_ads ^x.y.z, version not found" | pub.dev hasn't indexed the core yet. Wait a few minutes and re-run |
| `… is not on pub.dev yet` after 15 minutes | Check the package page. Re-run later, or pass `-WaitSeconds 1800` |
| The dry run reports warnings | Fix them before publishing. `dart pub publish` refuses to publish a package with warnings without confirming |
| Running `bash` in PowerShell says "This is WSL running the Windows Dart SDK" | Use `.\tool\publish.ps1`, or run the `.sh` from Git Bash |
| A brand-new package | It can be published the same way. Add it to `tool/lib/packages.sh` and `tool/publish.ps1` first |
