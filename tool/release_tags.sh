#!/usr/bin/env bash
# Tags every package whose pubspec version is not on pub.dev yet, in
# dependency order, so .github/workflows/publish.yml publishes it.
# Run by .github/workflows/release.yml after CI + iOS pass on master.
#
# Usage: tool/release_tags.sh [--dry-run]
#   --dry-run   print what would be tagged; never tags or pushes
#   RELEASE_WAIT_S=<s>   how long to wait for each version to appear on
#                        pub.dev before tagging dependents (default 900)
#
# For each package (tool/lib/packages.sh order):
#   version on pub.dev                → skip
#   tag <package>-v<version> missing  → tag HEAD, push the tag, wait for pub.dev
#   tag present, version not on pub.dev (a re-run) → only wait
# Waiting matters: adapters depend on the platform interface and the core, so
# those must be live on pub.dev before an adapter is published.
# Pushing needs a remote credential that can trigger workflows (the
# RELEASE_TAG_TOKEN PAT in release.yml); tags pushed with GITHUB_TOKEN don't.
set -euo pipefail

dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true
wait_s="${RELEASE_WAIT_S:-900}"

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=lib/packages.sh
source tool/lib/packages.sh

repo_url="https://github.com/rsagar024/unified_ads"

version_of() { sed -n 's/^version:[[:space:]]*//p' "packages/$1/pubspec.yaml" | head -1 | tr -d "\"'\r "; }

# 0 = listed, 1 = not listed, 2 = package unknown to pub.dev.
on_pub_dev() {
  local json status
  json="$(curl -sS -w '\n%{http_code}' "https://pub.dev/api/packages/$1")"
  status="${json##*$'\n'}"
  [[ "$status" == 404 ]] && return 2
  [[ "$status" != 200 ]] && { echo "pub.dev API returned HTTP $status for $1" >&2; exit 1; }
  grep -qF "\"version\":\"$2\"" <<< "${json%$'\n'*}"
}

remote_tag_exists() { [[ -n "$(git ls-remote --tags origin "refs/tags/$1")" ]]; }

wait_for() { # wait_for <package> <version> <tag>
  local deadline=$((SECONDS + wait_s))
  echo "    waiting for $1 $2 on pub.dev (up to ${wait_s}s)…"
  until on_pub_dev "$1" "$2"; do
    if ((SECONDS >= deadline)); then
      echo "    ✗ $1 $2 did not appear on pub.dev. Check the publish run for tag $3:" >&2
      echo "      $repo_url/actions/workflows/publish.yml" >&2
      exit 1
    fi
    sleep 20
  done
  echo "    ✓ $1 $2 is on pub.dev"
}

if ! $dry_run && [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean; refusing to tag." >&2
  exit 1
fi

sha="$(git rev-parse HEAD)"
mode=""
$dry_run && mode=" (dry run)"
echo "==> Release check at $sha$mode"
tagged=0
for p in "${PACKAGES[@]}"; do
  v="$(version_of "$p")"
  tag="$p-v$v"
  set +e
  on_pub_dev "$p" "$v"
  listed=$?
  set -e
  if ((listed == 0)); then
    echo "  $p $v: already on pub.dev → skip"
    continue
  fi
  if ((listed == 2)); then
    echo "  ✗ $p is not on pub.dev. Automated publishing only works for existing" >&2
    echo "    packages: publish its first version manually (tool/publish.sh)." >&2
    exit 1
  fi
  if remote_tag_exists "$tag"; then
    echo "  $p $v: tag $tag exists, not on pub.dev yet"
    $dry_run || wait_for "$p" "$v" "$tag"
    continue
  fi
  if $dry_run; then
    echo "  $p $v: would tag $tag"
    continue
  fi
  echo "  $p $v: tagging $tag"
  git tag -a "$tag" -m "$p $v" "$sha"
  git push origin "refs/tags/$tag"
  tagged=$((tagged + 1))
  wait_for "$p" "$v" "$tag"
done
echo "==> Done ($tagged tag(s) pushed)"
