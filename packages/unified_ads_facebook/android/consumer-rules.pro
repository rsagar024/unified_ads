# Consumer R8/ProGuard rules for unified_ads_facebook.
# The Facebook Audience Network SDK AAR ships its own consumer rules; keep the plugin entry point,
# which is referenced by name from GeneratedPluginRegistrant.
-keep class dev.arovyx.plugin.unifiedads.facebook.UnifiedAdsFacebookPlugin { *; }
