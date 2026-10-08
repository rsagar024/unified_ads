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

cd "$(dirname "$0")/.."

packages=(
  unified_ads_platform_interface
  unified_ads
  unified_ads_admob
  unified_ads_unity
  unified_ads_applovin
  unified_ads_ironsource
  unified_ads_facebook
  unified_ads_startapp
  unified_ads_inmobi
)

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
