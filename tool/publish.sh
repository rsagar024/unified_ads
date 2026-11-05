#!/usr/bin/env bash
# Validates (default) or publishes every package, in dependency order.
# Publishing is manual: see doc/publishing.md for the full release guide.
#
# Usage: tool/publish.sh              dry-run all packages
#        tool/publish.sh --publish    publish them to pub.dev (asks per package)
#          PUBLISH_WAIT_S=<s>         how long to wait for the platform interface
#                                     and core to appear on pub.dev (default 900)
#
# The repository root is the pub workspace (`publish_to: none`) and is never
# published: running `dart pub publish` there fails with "missing requirement".
#
# --publish only runs on a clean `master` that matches `origin/master`. A
# package whose pubspec version is already on pub.dev is skipped, so a re-run
# after a partial failure is safe. The adapters depend on the platform
# interface and the core, so after publishing those two the script waits until
# pub.dev lists them before it continues.
set -euo pipefail

# `bash` typed in PowerShell starts WSL, which then runs the Windows Flutter
# SDK's CRLF scripts and fails with "$'\r': command not found".
if grep -qi microsoft /proc/version 2>/dev/null && [[ "$(command -v dart)" == /mnt/* ]]; then
  echo "This is WSL running the Windows Dart SDK. Use .\\tool\\publish.ps1 from" >&2
  echo "PowerShell, or run this script from Git Bash." >&2
  exit 1
fi

cd "$(dirname "$0")/.."

# shellcheck source=lib/packages.sh
source tool/lib/packages.sh
packages=("${PACKAGES[@]}")

publish=false
[[ "${1:-}" == "--publish" ]] && publish=true
wait_s="${PUBLISH_WAIT_S:-900}"

version_of() { sed -n 's/^version:[[:space:]]*//p' "packages/$1/pubspec.yaml" | head -1 | tr -d "\"'\r "; }

# 0 = listed, 1 = not listed (or package unknown to pub.dev).
on_pub_dev() {
  local json status
  json="$(curl -sS -w '\n%{http_code}' "https://pub.dev/api/packages/$1")"
  status="${json##*$'\n'}"
  [[ "$status" == 404 ]] && return 1
  [[ "$status" != 200 ]] && { echo "pub.dev API returned HTTP $status for $1" >&2; exit 1; }
  grep -qF "\"version\":\"$2\"" <<< "${json%$'\n'*}"
}

wait_for() { # wait_for <package> <version>
  local deadline=$((SECONDS + wait_s))
  echo "    waiting for $1 $2 on pub.dev (up to ${wait_s}s)…"
  until on_pub_dev "$1" "$2"; do
    if ((SECONDS >= deadline)); then
      echo "    ✗ $1 $2 is not on pub.dev yet. Re-run this script later; published packages are skipped." >&2
      exit 1
    fi
    sleep 20
  done
  echo "    ✓ $1 $2 is on pub.dev"
}

if $publish; then
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" == master ]] ||
    { echo "On '$branch'. Publish from master: git checkout master && git pull" >&2; exit 1; }
  [[ -z "$(git status --porcelain)" ]] ||
    { echo "Working tree is not clean. Commit or stash your changes first." >&2; exit 1; }
  git fetch -q origin master
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/master)" ]] ||
    { echo "master differs from origin/master. Run: git pull" >&2; exit 1; }
fi

failed=()
for package in "${packages[@]}"; do
  version="$(version_of "$package")"
  echo "=== $package $version"
  if on_pub_dev "$package" "$version"; then
    echo "    already on pub.dev → skip"
    continue
  fi
  if ! $publish; then
    # A dry-run exits non-zero on warnings too: check every package first.
    (cd "packages/$package" && dart pub publish --dry-run) || failed+=("$package")
    continue
  fi
  (cd "packages/$package" && dart pub publish)
  case "$package" in
    unified_ads_platform_interface | unified_ads) wait_for "$package" "$version" ;;
  esac
done

if (( ${#failed[@]} )); then
  echo "Packages with warnings or errors: ${failed[*]}"
  exit 1
fi
