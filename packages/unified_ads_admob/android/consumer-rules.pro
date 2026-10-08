# Consumer R8/ProGuard rules for unified_ads_admob.
# GMA Next-Gen (ads-mobile-sdk) and UMP ship their own consumer rules, so
# nothing is required here. Adapter classes are referenced from Flutter's
# GeneratedPluginRegistrant and from Pigeon channels by name only, so keep the
# plugin entry point.
-keep class dev.arovyx.plugin.unifiedads.admob.UnifiedAdsAdmobPlugin { *; }

# Opt-in Meta bidding (MetaBidding.kt): the adapter is looked up by name. The
# rule only applies when the app adds the adapter; Audience Network keeps its
# own public classes (AdSettings).
-keepnames class com.google.ads.mediation.facebook.FacebookMediationAdapter
