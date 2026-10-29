# Validates (default) or publishes every package, in dependency order.
# PowerShell twin of tool/publish.sh. Publishing is manual: see
# doc/publishing.md for the full release guide.
#
# Usage: .\tool\publish.ps1              dry-run all packages
#        .\tool\publish.ps1 -Publish     publish them to pub.dev (asks per package)
#        -WaitSeconds <s>                how long to wait for the platform
#                                        interface and core to appear on pub.dev
#                                        (default 900)
#
# The repository root is the pub workspace (`publish_to: none`) and is never
# published.
#
# -Publish only runs on a clean `master` that matches `origin/master`. A
# package whose pubspec version is already on pub.dev is skipped, so a re-run
# after a partial failure is safe. The adapters depend on the platform
# interface and the core, so after publishing those two the script waits until
# pub.dev lists them before it continues.
param([switch]$Publish, [int]$WaitSeconds = 900)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$packages = @(
  'unified_ads_platform_interface'
  'unified_ads'
  'unified_ads_admob'
  'unified_ads_unity'
  'unified_ads_applovin'
  'unified_ads_ironsource'
  'unified_ads_facebook'
  'unified_ads_startapp'
  'unified_ads_inmobi'
)

function Get-PubspecVersion($package) {
  $line = Get-Content (Join-Path $root "packages\$package\pubspec.yaml") |
    Where-Object { $_ -match '^version:' } | Select-Object -First 1
  ($line -replace '^version:\s*', '').Trim(" `"'")
}

function Test-OnPubDev($package, $version) {
  try {
    $info = Invoke-RestMethod "https://pub.dev/api/packages/$package"
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) { return $false }
    throw
  }
  [bool]($info.versions | Where-Object { $_.version -eq $version })
}

function Wait-OnPubDev($package, $version) {
  $deadline = (Get-Date).AddSeconds($WaitSeconds)
  Write-Host "    waiting for $package $version on pub.dev (up to ${WaitSeconds}s)..."
  while (-not (Test-OnPubDev $package $version)) {
    if ((Get-Date) -ge $deadline) {
      Write-Host "    $package $version is not on pub.dev yet. Re-run this script later; published packages are skipped."
      exit 1
    }
    Start-Sleep -Seconds 20
  }
  Write-Host "    $package $version is on pub.dev"
}

if ($Publish) {
  $branch = git -C $root rev-parse --abbrev-ref HEAD
  if ($branch -ne 'master') {
    Write-Host "On '$branch'. Publish from master: git checkout master; git pull"
    exit 1
  }
  if (git -C $root status --porcelain) {
    Write-Host 'Working tree is not clean. Commit or stash your changes first.'
    exit 1
  }
  git -C $root fetch -q origin master
  if ((git -C $root rev-parse HEAD) -ne (git -C $root rev-parse origin/master)) {
    Write-Host 'master differs from origin/master. Run: git pull'
    exit 1
  }
}

$failed = @()
foreach ($package in $packages) {
  $version = Get-PubspecVersion $package
  Write-Host "=== $package $version"
  if (Test-OnPubDev $package $version) {
    Write-Host '    already on pub.dev -> skip'
    continue
  }
  Push-Location (Join-Path $root "packages\$package")
  try {
    if ($Publish) { dart pub publish } else { dart pub publish --dry-run }
    $ok = $LASTEXITCODE -eq 0
  } finally {
    Pop-Location
  }
  if (-not $ok) {
    # A dry-run exits non-zero on warnings too: check every package first.
    if ($Publish) { exit 1 }
    $failed += $package
    continue
  }
  if ($Publish -and $package -in 'unified_ads_platform_interface', 'unified_ads') {
    Wait-OnPubDev $package $version
  }
}

if ($failed.Count -gt 0) {
  Write-Host "Packages with warnings or errors: $($failed -join ' ')"
  exit 1
}
