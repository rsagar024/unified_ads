package dev.arovyx.plugin.unifiedads.ironsource

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Stands in for com.facebook.ads.AdSettings; records the reflective calls. */
@Suppress("unused") // Called by reflection.
internal object FakeAdSettings {
    var options: Array<String>? = null
    var country: Int? = null
    var mixedAudience: Boolean? = null

    @JvmStatic
    fun setDataProcessingOptions(options: Array<String>) {
        this.options = options
        country = null
    }

    @JvmStatic
    fun setDataProcessingOptions(options: Array<String>, country: Int, state: Int) {
        this.options = options
        this.country = country
    }

    @JvmStatic
    fun setMixedAudience(value: Boolean) {
        mixedAudience = value
    }
}

internal class MetaBiddingTest {
    private val fake = FakeAdSettings::class.java.name

    @Test
    fun detectsOnlyClassesOnTheClasspath() {
        assertEquals(fake, MetaBidding.detect(fake))
        assertNull(MetaBidding.detect("com.example.NotThere"))
        // The real adapter is not a dependency of this package.
        assertNull(MetaBidding.detect())
    }

    @Test
    fun ccpaOptOutBecomesLimitedDataUse() {
        assertTrue(MetaBidding.applyPrivacy(ccpaOptOut = true, coppa = true, adSettingsClass = fake))
        assertContentEquals(arrayOf("LDU"), FakeAdSettings.options)
        assertEquals(0, FakeAdSettings.country)
        assertEquals(true, FakeAdSettings.mixedAudience)

        MetaBidding.applyPrivacy(ccpaOptOut = false, coppa = false, adSettingsClass = fake)
        assertContentEquals(arrayOf(), FakeAdSettings.options)
        assertEquals(false, FakeAdSettings.mixedAudience)
    }

    @Test
    fun isANoOpWithoutAudienceNetwork() {
        assertFalse(MetaBidding.applyPrivacy(ccpaOptOut = true, coppa = true, adSettingsClass = "com.example.NotThere"))
    }
}
