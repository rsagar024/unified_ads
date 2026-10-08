package dev.arovyx.plugin.unifiedads.applovin

/**
 * Maps MAX error codes (MaxErrorCode, values from the 13.6.4 SDK) to
 * `AdErrorCode` names understood by the Dart side.
 */
internal object Errors {
    fun loadCode(code: Int): String = when (code) {
        204 -> "noFill" // NO_FILL
        -1000, -1009 -> "networkError" // NETWORK_ERROR, NO_NETWORK
        -1001 -> "timeout" // NETWORK_TIMEOUT
        -5603 -> "invalidConfig" // INVALID_AD_UNIT_ID
        else -> "internal" // AD_LOAD_FAILED (-5001), UNSPECIFIED (-1), …
    }

    fun showCode(code: Int): String = when (code) {
        -23 -> "alreadyShowing" // FULLSCREEN_AD_ALREADY_SHOWING
        -24 -> "notReady" // FULLSCREEN_AD_NOT_READY
        -5602 -> "noActivity" // DONT_KEEP_ACTIVITIES_ENABLED
        else -> "showFailed"
    }

    fun load(code: Int, message: String?) =
        FlutterError(loadCode(code), message ?: "AppLovin MAX load failed", code.toString())

    fun show(code: Int, message: String?) =
        FlutterError(showCode(code), message ?: "AppLovin MAX show failed", code.toString())

    fun of(code: String, message: String) = FlutterError(code, message, null)
}
