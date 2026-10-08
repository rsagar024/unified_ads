# Consumer R8/ProGuard rules for unified_ads_applovin.
# The AppLovin MAX SDK AAR ships its own consumer rules; keep the plugin entry point,
# which is referenced by name from GeneratedPluginRegistrant.
-keep class dev.arovyx.plugin.unifiedads.applovin.UnifiedAdsApplovinPlugin { *; }

# Opt-in Meta bidding (MetaBidding.kt): the adapter is looked up by name. The
# rule only applies when the app adds the adapter; Audience Network keeps its
# own public classes (AdSettings).
-keepnames class com.applovin.mediation.adapters.FacebookMediationAdapter
