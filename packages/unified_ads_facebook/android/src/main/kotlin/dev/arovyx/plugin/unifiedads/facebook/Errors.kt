package dev.arovyx.plugin.unifiedads.facebook

/**
 * Maps Audience Network `AdError` codes (values verified with javap on SDK
 * 6.22.0) to `AdErrorCode` names understood by Dart.
 */
internal object Errors {
    fun loadCode(code: Int): String = when (code) {
        1001 -> "noFill" // NO_FILL_ERROR_CODE
        1000 -> "networkError" // NETWORK_ERROR_CODE
        2000 -> "networkError" // SERVER_ERROR_CODE
        1002 -> "frequencyCapped" // LOAD_TOO_FREQUENTLY_ERROR_CODE
        2009 -> "timeout" // INTERSTITIAL_AD_TIMEOUT
        7003 -> "invalidConfig" // CLEAR_TEXT_SUPPORT_NOT_ALLOWED (network_security_config)
        7005, 7006 -> "invalidConfig" // MISSING_DEPENDENCIES_ERROR, API_NOT_SUPPORTED
        1011, 1203 -> "invalidConfig" // placement used with the wrong display format (seen on device)
        7002 -> "alreadyShowing" // LOAD_CALLED_WHILE_SHOWING_AD
        else -> "internal" // INTERNAL_ERROR_CODE (2001), CACHE_ERROR_CODE (2002), …
    }

    fun showCode(code: Int): String = when (code) {
        7001 -> "notReady" // SHOW_CALLED_BEFORE_LOAD_ERROR_CODE
        7004 -> "notReady" // INCORRECT_STATE_ERROR
        else -> "showFailed" // AD_PRESENTATION_ERROR_CODE (9001), …
    }

    fun load(code: Int, message: String?) =
        FlutterError(loadCode(code), message ?: "Audience Network load failed", code.toString())

    fun show(code: Int, message: String?) =
        FlutterError(showCode(code), message ?: "Audience Network show failed", code.toString())

    fun of(code: String, message: String) = FlutterError(code, message, null)
}
