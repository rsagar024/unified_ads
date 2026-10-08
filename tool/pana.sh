#!/usr/bin/env bash
# Runs pana (the pub.dev scorer) on one or more workspace packages.
#
# Usage: tool/pana.sh [package ...]     (default: every package in packages/)
#   PANA_MAX_LOST=<points>   fail if a package loses more points (default: off)
#   PANA_KEEP=1              keep the temp copies and pana logs
#
# The packages aren't published yet, so pana can't resolve
# `unified_ads_platform_interface: ^1.0.0` from pub.dev. Each package is
# therefore copied to a temp dir, `resolution: workspace` is stripped, and a
# pubspec_overrides.yaml points the sibling packages at this checkout.
# Requires: dart pub global activate pana
# Linux/macOS only: pana's sandbox rejects paths containing ":" (any Windows
# drive path), so on Windows it runs in CI only.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_sdk="$(dirname "$(dirname "$(command -v flutter)")")"

if (($# == 0)); then
  set -- $(cd "$repo/packages" && ls -d unified_ads*)
fi

workdir="$(mktemp -d)"
trap '[[ -n "${PANA_KEEP:-}" ]] || rm -rf "$workdir"' EXIT
status=0
summary=()

for pkg in "$@"; do
  src="$repo/packages/$pkg"
  dst="$workdir/$pkg"
  echo "==> pana $pkg"
  cp -r "$src" "$dst"
  # Drop local build output that pub would not publish.
  rm -rf "$dst/build" "$dst/.dart_tool" "$dst/android/.gradle" "$dst/android/build" \
    "$dst/android/local.properties" "$dst/ios/.build" "$dst/ios/.swiftpm" \
    "$dst/.idea" "$dst/pubspec.lock" "$dst/.flutter-plugins-dependencies"
  find "$dst" -name '*.iml' -delete
  sed -i.bak '/^resolution: workspace/d' "$dst/pubspec.yaml" && rm "$dst/pubspec.yaml.bak"
  {
    echo 'dependency_overrides:'
    for sibling in unified_ads_platform_interface unified_ads; do
      [[ "$sibling" == "$pkg" ]] || printf '  %s:\n    path: %s\n' "$sibling" "$repo/packages/$sibling"
    done
  } > "$dst/pubspec_overrides.yaml"
  log="$workdir/$pkg.log"
  args=(--no-warning --flutter-sdk "$flutter_sdk")
  [[ -n "${PANA_MAX_LOST:-}" ]] && args+=(--exit-code-threshold "$PANA_MAX_LOST")
  if dart pub global run pana "${args[@]}" "$dst" > "$log" 2>&1; then
    result=ok
  else
    result=FAIL
    status=1
  fi
  points="$(grep -Eo 'Points: [0-9]+/[0-9]+' "$log" | tail -1 || true)"
  # Print every section that lost points, so CI logs show what to fix.
  awk '/^## \[x\]|^## \[\*\]|^### \[x\]|^### \[\*\]/ { show = 1 } /^## \[\+\]|^### \[\+\]/ { show = 0 } show' "$log"
  summary+=("$pkg: ${points:-no score} ($result)")
done

echo
echo "==> pana summary"
printf '  %s\n' "${summary[@]}"
exit "$status"
