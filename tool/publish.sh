#!/usr/bin/env bash
# Validates (default) or publishes every package, in dependency order.
#
# Usage: tool/publish.sh              dry-run all packages
#        tool/publish.sh --publish    publish them to pub.dev (asks per package)
#
# The repository root is the pub workspace (`publish_to: none`) and is never
# published: running `dart pub publish` there fails with "missing requirement".
# The adapters depend on `^1.0.0` of the platform interface and the core, so
# those two must reach pub.dev first.
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

mode=--dry-run
[[ "${1:-}" == "--publish" ]] && mode=

failed=()
for package in "${packages[@]}"; do
  echo "=== $package"
  if ! (cd "packages/$package" && dart pub publish $mode); then
    # A dry-run exits non-zero on warnings too: check every package first.
    [[ -z "$mode" ]] && exit 1
    failed+=("$package")
  fi
done

if (( ${#failed[@]} )); then
  echo "Packages with warnings or errors: ${failed[*]}"
  exit 1
fi
