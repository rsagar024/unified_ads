package dev.arovyx.plugin.unifiedads.applovin

import kotlin.test.Test
import kotlin.test.assertEquals

internal class ErrorsTest {
    @Test
    fun loadCodes() {
        assertEquals("noFill", Errors.loadCode(204))
        assertEquals("networkError", Errors.loadCode(-1000))
        assertEquals("networkError", Errors.loadCode(-1009))
        assertEquals("timeout", Errors.loadCode(-1001))
        assertEquals("invalidConfig", Errors.loadCode(-5603))
        assertEquals("internal", Errors.loadCode(-5001))
    }

    @Test
    fun showCodes() {
        assertEquals("alreadyShowing", Errors.showCode(-23))
        assertEquals("notReady", Errors.showCode(-24))
        assertEquals("noActivity", Errors.showCode(-5602))
        assertEquals("showFailed", Errors.showCode(-1))
    }

    @Test
    fun keepsNativeCode() {
        assertEquals("204", Errors.load(204, "No fill").details)
    }
}
