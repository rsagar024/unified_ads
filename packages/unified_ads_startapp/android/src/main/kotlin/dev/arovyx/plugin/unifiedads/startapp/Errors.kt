package dev.arovyx.plugin.unifiedads.startapp

/**
 * Start.io exposes no numeric error codes (only a message and an obfuscated
 * "not displayed" reason), so failures map to fixed `AdErrorCode` names.
 */
internal object Errors {
    fun of(code: String, message: String) = FlutterError(code, message, null)

    /** Banner size in dp for a `BannerSize` type name. */
    fun bannerSize(type: String?): Pair<Int, Int> = when (type) {
        "mediumRectangle" -> 300 to 250
        else -> 320 to 50
    }
}
