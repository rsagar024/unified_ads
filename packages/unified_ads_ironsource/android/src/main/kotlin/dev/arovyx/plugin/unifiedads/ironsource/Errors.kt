package dev.arovyx.plugin.unifiedads.ironsource

/**
 * Maps LevelPlay error codes (from the 9.6.1 SDK constants / ISError.h) to
 * `AdErrorCode` names understood by Dart.
 */
internal object Errors {
    fun loadCode(code: Int): String = when (code) {
        509, 606, 1024, 1035, 1044, 1158 -> "noFill" // no ads / no candidates (1044: banner, seen on device)
        520 -> "networkError" // no internet
        524, 525, 526, 530 -> "frequencyCapped" // placement / format / session / ad-unit capped
        624, 626 -> "invalidConfig" // missing / invalid ad unit ID
        625 -> "notInitialized" // load before init success
        627, 629 -> "alreadyShowing" // load while loading / showing
        else -> "internal"
    }

    fun showCode(code: Int): String = when (code) {
        628, 631 -> "notReady" // show before load / show while loading
        630 -> "alreadyShowing"
        524, 525, 526, 530 -> "frequencyCapped"
        else -> "showFailed"
    }

    fun load(code: Int, message: String?) =
        FlutterError(loadCode(code), message ?: "LevelPlay load failed", code.toString())

    fun show(code: Int, message: String?) =
        FlutterError(showCode(code), message ?: "LevelPlay show failed", code.toString())

    fun of(code: String, message: String) = FlutterError(code, message, null)
}
