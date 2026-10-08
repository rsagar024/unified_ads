package dev.arovyx.plugin.unifiedads.inmobi

import kotlin.test.Test
import kotlin.test.assertEquals

internal class ErrorsTest {
    @Test
    fun statusCodes() {
        assertEquals("noFill", Errors.statusCode("NO_FILL"))
        assertEquals("networkError", Errors.statusCode("NETWORK_UNREACHABLE"))
        assertEquals("timeout", Errors.statusCode("REQUEST_TIMED_OUT"))
        assertEquals("invalidConfig", Errors.statusCode("REQUEST_INVALID"))
        assertEquals("alreadyShowing", Errors.statusCode("AD_ACTIVE"))
        assertEquals("internal", Errors.statusCode("FEATURE_DISABLED"))
    }

    @Test
    fun firstRewardEntry() {
        assertEquals("coins" to 10.0, Errors.firstReward(mapOf("coins" to 10)))
        assertEquals("gems" to 2.5, Errors.firstReward(mapOf("gems" to "2.5")))
        assertEquals("reward" to 1.0, Errors.firstReward(emptyMap<Any, Any>()))
    }
}
