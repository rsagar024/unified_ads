package dev.arovyx.plugin.unifiedads.applovin

import android.util.Log

/**
 * Optional Meta (Facebook) Audience Network bidding through AppLovin MAX mediation.
 *
 * This package declares no Meta dependency. An app opts in by adding the
 * vendor's Meta adapter to its own build (see docs/setup/applovin.md). This object
 * then detects the adapter and forwards privacy signals to the Audience Network
 * SDK before AppLovin MAX initializes it, all by reflection so the package compiles
 * and links without Meta's SDK.
 */
internal object MetaBidding {
    /** The Meta adapter class shipped by `com.applovin.mediation:facebook-adapter`. */
    const val ADAPTER_CLASS = "com.applovin.mediation.adapters.FacebookMediationAdapter"

    private const val AD_SETTINGS_CLASS = "com.facebook.ads.AdSettings"
    private const val LOG_TAG = "UnifiedAdsMetaBidding"

    /** Returns [className] when the app added the Meta adapter, otherwise null. */
    fun detect(className: String = ADAPTER_CLASS): String? = runCatching {
        Class.forName(className, false, MetaBidding::class.java.classLoader)
        className
    }.getOrNull()

    /**
     * Applies the app's privacy choices to Audience Network's static settings:
     * CCPA opt-out becomes Limited Data Use, COPPA becomes mixed audience.
     * Returns false (and does nothing) when the Audience Network SDK is absent.
     */
    fun applyPrivacy(
        ccpaOptOut: Boolean?,
        coppa: Boolean,
        adSettingsClass: String = AD_SETTINGS_CLASS,
    ): Boolean {
        val settings = runCatching {
            Class.forName(adSettingsClass, true, MetaBidding::class.java.classLoader)
        }.getOrNull() ?: return false
        runCatching {
            when (ccpaOptOut) {
                true -> settings
                    .getMethod(
                        "setDataProcessingOptions",
                        Array<String>::class.java,
                        Int::class.javaPrimitiveType,
                        Int::class.javaPrimitiveType,
                    )
                    .invoke(null, arrayOf("LDU"), 0, 0)
                false -> settings
                    .getMethod("setDataProcessingOptions", Array<String>::class.java)
                    .invoke(null, arrayOf<String>())
                null -> Unit
            }
            settings.getMethod("setMixedAudience", Boolean::class.javaPrimitiveType).invoke(null, coppa)
        }.onFailure { Log.w(LOG_TAG, "Could not apply privacy settings to Audience Network", it) }
        return true
    }
}
