package dev.arovyx.plugin.unifiedads.inmobi

import com.inmobi.ads.InMobiAdRequestStatus

/** Maps InMobi request statuses to `AdErrorCode` names understood by Dart. */
internal object Errors {
    /** [name] is an `InMobiAdRequestStatus.StatusCode` constant name. */
    fun statusCode(name: String): String = when (name) {
        "NO_FILL", "AD_NO_LONGER_AVAILABLE" -> "noFill"
        "NETWORK_UNREACHABLE", "SERVER_ERROR" -> "networkError"
        "REQUEST_TIMED_OUT" -> "timeout"
        "REQUEST_INVALID", "CONFIGURATION_ERROR", "MONETIZATION_DISABLED", "MISSING_REQUIRED_DEPENDENCIES" ->
            "invalidConfig"
        "AD_ACTIVE" -> "alreadyShowing"
        else -> "internal"
    }

    fun status(status: InMobiAdRequestStatus): FlutterError {
        val name = status.statusCode.name
        return FlutterError(statusCode(name), status.message ?: "InMobi request failed", name)
    }

    /** First entry of InMobi's rewards map as (type, amount); amount defaults to 1. */
    fun firstReward(rewards: Map<*, *>): Pair<String, Double> {
        val entry = rewards.entries.firstOrNull() ?: return "reward" to 1.0
        val amount = (entry.value as? Number)?.toDouble() ?: entry.value?.toString()?.toDoubleOrNull() ?: 1.0
        return entry.key.toString() to amount
    }

    fun of(code: String, message: String) = FlutterError(code, message, null)
}
