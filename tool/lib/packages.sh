# Publishable packages in dependency order: the platform interface first, then
# the core (both depended on by every adapter), then the adapters. Shared by
# tool/publish.sh (mirrored in tool/publish.ps1). Source it; defines PACKAGES only.
PACKAGES=(
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
