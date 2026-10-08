package dev.arovyx.plugin.unifiedads.facebook

import kotlin.test.Test
import kotlin.test.assertEquals

internal class ErrorsTest {
    @Test
    fun loadCodes() {
        assertEquals("noFill", Errors.loadCode(1001))
        assertEquals("networkError", Errors.loadCode(1000))
        assertEquals("networkError", Errors.loadCode(2000))
        assertEquals("frequencyCapped", Errors.loadCode(1002))
        assertEquals("timeout", Errors.loadCode(2009))
        assertEquals("invalidConfig", Errors.loadCode(7003))
        assertEquals("invalidConfig", Errors.loadCode(1203))
        assertEquals("internal", Errors.loadCode(2001))
    }

    @Test
    fun showCodes() {
        assertEquals("notReady", Errors.showCode(7001))
        assertEquals("notReady", Errors.showCode(7004))
        assertEquals("showFailed", Errors.showCode(9001))
    }

    @Test
    fun keepsNativeCode() {
        assertEquals("1001", Errors.load(1001, "No fill").details)
    }
}
