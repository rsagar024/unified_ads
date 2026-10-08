# Consumer R8/ProGuard rules for unified_ads_unity.
# The Unity Ads SDK AAR ships its own consumer rules; keep the plugin entry point,
# which is referenced by name from GeneratedPluginRegistrant.
-keep class dev.arovyx.plugin.unifiedads.unity.UnifiedAdsUnityPlugin { *; }
