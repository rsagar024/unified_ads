package dev.arovyx.plugin.unifiedads.unity

import kotlin.test.Test
import kotlin.test.assertEquals

internal class ErrorsTest {
    @Test
    fun initCodes() {
        assertEquals("invalidConfig", Errors.initCode(52001))
        assertEquals("invalidConfig", Errors.initCode(52002))
        assertEquals("networkError", Errors.initCode(52005))
        assertEquals("initializationFailed", Errors.initCode(52000))
    }

    @Test
    fun loadCodes() {
        assertEquals("noFill", Errors.loadCode(52100))
        assertEquals("notInitialized", Errors.loadCode(52101))
        assertEquals("invalidConfig", Errors.loadCode(52102))
        assertEquals("timeout", Errors.loadCode(2))
        assertEquals("internal", Errors.loadCode(52103))
    }

    @Test
    fun showCodes() {
        assertEquals("notReady", Errors.showCode(52200))
        assertEquals("alreadyShowing", Errors.showCode(52201))
        assertEquals("showFailed", Errors.showCode(52202))
    }
}
