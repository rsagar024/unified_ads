package dev.arovyx.plugin.unifiedads.unity

/**
 * Maps `UnityAdsError.code` values to `AdErrorCode` names understood by Dart.
 * Codes from Unity's 4.19+ migration guide; the 520xx init/load/show codes
 * marked ⚠ come from the AppLovin Unity adapter source (not an official table).
 */
internal object Errors {
    const val NO_FILL = 52100

    fun loadCode(code: Int): String = when (code) {
        52100 -> "noFill"
        52101 -> "notInitialized"
        52102, 52104 -> "invalidConfig" // placement not found / unsupported placement
        2 -> "timeout"
        52005, 52105 -> "networkError" // ⚠
        else -> "internal"
    }

    fun showCode(code: Int): String = when (code) {
        52200 -> "notReady" // ⚠ expired
        52201 -> "alreadyShowing" // ⚠
        else -> "showFailed"
    }

    fun load(code: Int, message: String?) =
        FlutterError(loadCode(code), message ?: "Unity Ads load failed", code.toString())

    fun show(code: Int, message: String?) =
        FlutterError(showCode(code), message ?: "Unity Ads show failed", code.toString())

    fun of(code: String, message: String) = FlutterError(code, message, null)
}
