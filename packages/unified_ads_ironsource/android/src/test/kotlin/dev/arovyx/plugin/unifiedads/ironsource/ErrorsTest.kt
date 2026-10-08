package dev.arovyx.plugin.unifiedads.ironsource

import kotlin.test.Test
import kotlin.test.assertEquals

internal class ErrorsTest {
    @Test
    fun loadCodes() {
        assertEquals("noFill", Errors.loadCode(509))
        assertEquals("noFill", Errors.loadCode(1158))
        assertEquals("noFill", Errors.loadCode(1044))
        assertEquals("networkError", Errors.loadCode(520))
        assertEquals("frequencyCapped", Errors.loadCode(524))
        assertEquals("invalidConfig", Errors.loadCode(626))
        assertEquals("notInitialized", Errors.loadCode(625))
        assertEquals("internal", Errors.loadCode(510))
    }

    @Test
    fun showCodes() {
        assertEquals("notReady", Errors.showCode(628))
        assertEquals("alreadyShowing", Errors.showCode(630))
        assertEquals("showFailed", Errors.showCode(510))
    }
}
