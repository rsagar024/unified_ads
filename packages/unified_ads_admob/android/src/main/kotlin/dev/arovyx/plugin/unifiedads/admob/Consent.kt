package dev.arovyx.plugin.unifiedads.admob

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import com.google.android.ump.ConsentDebugSettings
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.FormError
import com.google.android.ump.UserMessagingPlatform
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/** Google UMP consent flow plus the IAB values UMP stores on the device. */
internal object Consent {
    suspend fun gather(activity: Activity, request: GatherRequest): ConsentInfo {
        val info = UserMessagingPlatform.getConsentInformation(activity)
        val params = ConsentRequestParameters.Builder().apply {
            val geography = request.debugGeography
            if (geography != null || request.testDeviceHashedIds.isNotEmpty()) {
                val debug = ConsentDebugSettings.Builder(activity)
                // DebugGeography values: EEA = 1, REGULATED_US_STATE = 3, OTHER = 4.
                when (geography) {
                    DebugGeographyMessage.EEA -> debug.setDebugGeography(1)
                    DebugGeographyMessage.REGULATED_US_STATE -> debug.setDebugGeography(3)
                    DebugGeographyMessage.OTHER -> debug.setDebugGeography(4)
                    null -> Unit
                }
                request.testDeviceHashedIds.forEach { debug.addTestDeviceHashedId(it) }
                setConsentDebugSettings(debug.build())
            }
        }.build()

        suspendCancellableCoroutine { cont ->
            info.requestConsentInfoUpdate(
                activity,
                params,
                { if (cont.isActive) cont.resume(Unit) },
                { error -> if (cont.isActive) cont.resumeWithException(formError(error)) },
            )
        }

        val formError = suspendCancellableCoroutine<FormError?> { cont ->
            val done = { error: FormError? -> if (cont.isActive) cont.resume(error) }
            if (request.forceForm &&
                info.privacyOptionsRequirementStatus ==
                ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
            ) {
                UserMessagingPlatform.showPrivacyOptionsForm(activity) { done(it) }
            } else {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { done(it) }
            }
        }
        // A form error (e.g. no form configured) is not fatal: report the state.
        formError?.let { android.util.Log.w(TAG, "UMP form: ${it.errorCode} ${it.message}") }
        return snapshot(activity)
    }

    suspend fun showPrivacyOptions(activity: Activity) {
        val error = suspendCancellableCoroutine<FormError?> { cont ->
            UserMessagingPlatform.showPrivacyOptionsForm(activity) { if (cont.isActive) cont.resume(it) }
        }
        if (error != null) throw formError(error)
    }

    fun snapshot(context: Context): ConsentInfo {
        val info = UserMessagingPlatform.getConsentInformation(context)
        val prefs = defaultPreferences(context)
        return ConsentInfo(
            canRequestAds = info.canRequestAds(),
            privacyOptionsRequired = info.privacyOptionsRequirementStatus ==
                ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED,
            gdprApplies = readInt(prefs, "IABTCF_gdprApplies"),
            tcString = prefs.getString("IABTCF_TCString", null),
            purposeConsents = prefs.getString("IABTCF_PurposeConsents", null),
            gppString = prefs.getString("IABGPP_HDR_GppString", null),
        )
    }

    /** The app's default SharedPreferences, where UMP / IAB and `gad_rdp` live. */
    fun defaultPreferences(context: Context): SharedPreferences =
        context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)

    private fun readInt(prefs: SharedPreferences, key: String): Long? {
        if (!prefs.contains(key)) return null
        return runCatching { prefs.getInt(key, 0).toLong() }
            .recoverCatching { prefs.getString(key, null)?.toLong() }
            .getOrNull()
    }

    private fun formError(error: FormError): FlutterError {
        // FormError.ErrorCode.INTERNET_ERROR = 2, TIME_OUT = 4.
        val code = when (error.errorCode) {
            2 -> "networkError"
            4 -> "timeout"
            else -> "internal"
        }
        return FlutterError(code, error.message, error.errorCode.toString())
    }
}
