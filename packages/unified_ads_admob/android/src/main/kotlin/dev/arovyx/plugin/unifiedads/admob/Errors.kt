package dev.arovyx.plugin.unifiedads.admob

import com.google.android.libraries.ads.mobile.sdk.common.FullScreenContentError
import com.google.android.libraries.ads.mobile.sdk.common.LoadAdError

/**
 * Maps GMA Next-Gen error codes to `AdErrorCode` names understood by the Dart
 * side. Next-Gen reports codes as enums (LoadAdError.ErrorCode,
 * FullScreenContentError.ErrorCode), so the mapping is by enum constant and the
 * native code sent to Dart is the constant's name.
 */
internal object Errors {
    /** Load error code → AdErrorCode name. */
    fun loadCode(code: LoadAdError.ErrorCode): String = when (code) {
        LoadAdError.ErrorCode.NO_FILL -> "noFill"
        LoadAdError.ErrorCode.NETWORK_ERROR -> "networkError"
        LoadAdError.ErrorCode.TIMEOUT -> "timeout"
        LoadAdError.ErrorCode.INVALID_REQUEST,
        LoadAdError.ErrorCode.APP_ID_MISSING,
        LoadAdError.ErrorCode.NOT_FOUND,
        -> "invalidConfig"
        else -> "internal" // INTERNAL_ERROR, CANCELLED, REQUEST_ID_MISMATCH, …
    }

    /** Show error code → AdErrorCode name. */
    fun showCode(code: FullScreenContentError.ErrorCode): String = when (code) {
        FullScreenContentError.ErrorCode.AD_REUSED,
        FullScreenContentError.ErrorCode.H5_SHOW_AD_NOT_LOADED,
        -> "notReady"
        FullScreenContentError.ErrorCode.APP_NOT_FOREGROUND -> "noActivity"
        else -> "showFailed" // INTERNAL_ERROR, MEDIATION_SHOW_ERROR
    }

    fun load(error: LoadAdError) =
        FlutterError(loadCode(error.code), error.message.ifBlank { "AdMob load failed" }, error.code.name)

    fun show(error: FullScreenContentError) =
        FlutterError(showCode(error.code), error.message.ifBlank { "AdMob show failed" }, error.code.name)

    fun of(code: String, message: String) = FlutterError(code, message, null)
}
