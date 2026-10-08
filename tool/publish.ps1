# Validates (default) or publishes every package, in dependency order.
# PowerShell twin of tool/publish.sh.
#
# Usage: .\tool\publish.ps1              dry-run all packages
#        .\tool\publish.ps1 -Publish     publish them to pub.dev (asks per package)
#
# The repository root is the pub workspace (`publish_to: none`) and is never
# published. The adapters depend on `^1.0.0` of the platform interface and the
# core, so those two must reach pub.dev first.
param([switch]$Publish)

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

$failed = @()
foreach ($package in $packages) {
  Write-Host "=== $package"
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
  }
}

if ($failed.Count -gt 0) {
  Write-Host "Packages with warnings or errors: $($failed -join ' ')"
  exit 1
}
