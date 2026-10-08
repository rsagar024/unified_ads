package dev.arovyx.plugin.unifiedads.startapp

import kotlin.test.Test
import kotlin.test.assertEquals

internal class ErrorsTest {
    @Test
    fun bannerSizes() {
        assertEquals(300 to 250, Errors.bannerSize("mediumRectangle"))
        assertEquals(320 to 50, Errors.bannerSize("standard"))
        assertEquals(320 to 50, Errors.bannerSize("adaptiveAnchored"))
        assertEquals(320 to 50, Errors.bannerSize(null))
    }

    @Test
    fun errorsHaveNoNativeCode() {
        val error = Errors.of("noFill", "none")
        assertEquals("noFill", error.code)
        assertEquals(null, error.details)
    }
}
