# Changelog

This repository is a pub workspace. Each package is versioned and published on its own, and keeps its own changelog:

| Package | Changelog |
|---|---|
| `unified_ads_platform_interface` | [packages/unified_ads_platform_interface/CHANGELOG.md](packages/unified_ads_platform_interface/CHANGELOG.md) |
| `unified_ads` | [packages/unified_ads/CHANGELOG.md](packages/unified_ads/CHANGELOG.md) |
| `unified_ads_admob` | [packages/unified_ads_admob/CHANGELOG.md](packages/unified_ads_admob/CHANGELOG.md) |
| `unified_ads_unity` | [packages/unified_ads_unity/CHANGELOG.md](packages/unified_ads_unity/CHANGELOG.md) |
| `unified_ads_applovin` | [packages/unified_ads_applovin/CHANGELOG.md](packages/unified_ads_applovin/CHANGELOG.md) |
| `unified_ads_ironsource` | [packages/unified_ads_ironsource/CHANGELOG.md](packages/unified_ads_ironsource/CHANGELOG.md) |
| `unified_ads_facebook` | [packages/unified_ads_facebook/CHANGELOG.md](packages/unified_ads_facebook/CHANGELOG.md) |
| `unified_ads_startapp` | [packages/unified_ads_startapp/CHANGELOG.md](packages/unified_ads_startapp/CHANGELOG.md) |
| `unified_ads_inmobi` | [packages/unified_ads_inmobi/CHANGELOG.md](packages/unified_ads_inmobi/CHANGELOG.md) |

## 1.1.0

iOS is Swift Package Manager only (see each package's changelog and
[the migration guide](doc/migration/1.1.0-swift-package-manager.md)). All nine packages were also re-verified against every vendor's current Android and iOS integration guide (2026-10-28; see
[SDK_STATUS.md §3.8](SDK_STATUS.md#38-re-verification-against-the-vendors-current-guides-2026-10-28-110)). No Dart API
changes. SDKs: GMA Next-Gen 1.6.0, LevelPlay 9.7.0, InMobi Android 11.5.1, FBAudienceNetwork iOS 6.22.1. Fixes: Unity
expired ads, LevelPlay iOS `setMetaData(withKey:value:)`, InMobi iOS `libz` + consent at init, Start.io iOS ad tag and
error codes, the Audience Network ATT flag below iOS 17. Each package README is now package-specific;
`unified_ads` carries the full guide.

## 1.0.0

Initial release of all nine packages.
