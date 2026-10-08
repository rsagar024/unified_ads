package dev.arovyx.plugin.unifiedads.admob

import com.google.android.libraries.ads.mobile.sdk.common.FullScreenContentError
import com.google.android.libraries.ads.mobile.sdk.common.LoadAdError
import kotlin.test.Test
import kotlin.test.assertEquals

internal class ErrorsTest {
    @Test
    fun loadCodesMapToAdErrorCodes() {
        assertEquals("noFill", Errors.loadCode(LoadAdError.ErrorCode.NO_FILL))
        assertEquals("networkError", Errors.loadCode(LoadAdError.ErrorCode.NETWORK_ERROR))
        assertEquals("timeout", Errors.loadCode(LoadAdError.ErrorCode.TIMEOUT))
        assertEquals("invalidConfig", Errors.loadCode(LoadAdError.ErrorCode.INVALID_REQUEST))
        assertEquals("invalidConfig", Errors.loadCode(LoadAdError.ErrorCode.APP_ID_MISSING))
        assertEquals("invalidConfig", Errors.loadCode(LoadAdError.ErrorCode.NOT_FOUND))
        assertEquals("internal", Errors.loadCode(LoadAdError.ErrorCode.INTERNAL_ERROR))
        assertEquals("internal", Errors.loadCode(LoadAdError.ErrorCode.CANCELLED))
        assertEquals("internal", Errors.loadCode(LoadAdError.ErrorCode.REQUEST_ID_MISMATCH))
    }

    @Test
    fun everyLoadCodeIsMapped() {
        val known = setOf("noFill", "networkError", "timeout", "invalidConfig", "internal")
        LoadAdError.ErrorCode.values().forEach { assert(Errors.loadCode(it) in known) }
    }

    @Test
    fun showCodesMapToAdErrorCodes() {
        assertEquals("notReady", Errors.showCode(FullScreenContentError.ErrorCode.AD_REUSED))
        assertEquals("notReady", Errors.showCode(FullScreenContentError.ErrorCode.H5_SHOW_AD_NOT_LOADED))
        assertEquals("noActivity", Errors.showCode(FullScreenContentError.ErrorCode.APP_NOT_FOREGROUND))
        assertEquals("showFailed", Errors.showCode(FullScreenContentError.ErrorCode.INTERNAL_ERROR))
        assertEquals("showFailed", Errors.showCode(FullScreenContentError.ErrorCode.MEDIATION_SHOW_ERROR))
    }

    @Test
    fun errorsCarryTheNativeCodeName() {
        val error = Errors.load(LoadAdError(LoadAdError.ErrorCode.NO_FILL, "No fill.", null))
        assertEquals("noFill", error.code)
        assertEquals("No fill.", error.message)
        assertEquals("NO_FILL", error.details)
    }
}
