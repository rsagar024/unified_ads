package dev.arovyx.plugin.unifiedads.inmobi

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.inmobi.ads.AdMetaInfo
import com.inmobi.ads.InMobiAdRequestStatus
import com.inmobi.ads.InMobiInterstitial
import com.inmobi.ads.listeners.InterstitialAdEventListener
import com.inmobi.compliance.InMobiPrivacyCompliance
import com.inmobi.sdk.InMobiSdk
import com.inmobi.sdk.SdkInitializationListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.lang.ref.WeakReference
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONObject

internal const val BANNER_VIEW_TYPE = "dev.arovyx.plugin.unifiedads/inmobi/banner"

/**
 * InMobi adapter plugin. Interstitial and rewarded ads both use
 * `InMobiInterstitial` (a rewarded placement unlocks rewards).
 */
class UnifiedAdsInmobiPlugin : FlutterPlugin, ActivityAware, InmobiHostApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var events: InmobiEventsApi? = null
    private var activityRef: WeakReference<Activity>? = null
    private var initialized = false
    private var counter = 0
    private var consent: ConsentMessage? = null
    private val ads = mutableMapOf<String, Holder>()

    internal val activity: Activity? get() = activityRef?.get()

    private inner class Holder(val id: String, val format: AdFormatMessage) : InterstitialAdEventListener() {
        var ad: InMobiInterstitial? = null
        var loadCont: CancellableContinuation<String>? = null
        var showCont: CancellableContinuation<Unit>? = null

        private fun send(kind: AdEventKind) = emit(AdEventMessage(kind, id, format))

        override fun onAdLoadSucceeded(ad: InMobiInterstitial, info: AdMetaInfo) {
            send(AdEventKind.LOADED)
            loadCont?.takeIf { it.isActive }?.resume(id)
            loadCont = null
        }

        override fun onAdLoadFailed(ad: InMobiInterstitial, status: InMobiAdRequestStatus) {
            ads.remove(id)
            loadCont?.takeIf { it.isActive }?.resumeWithException(Errors.status(status))
            loadCont = null
        }

        override fun onAdDisplayed(ad: InMobiInterstitial, info: AdMetaInfo) {
            send(AdEventKind.SHOWN)
            showCont?.takeIf { it.isActive }?.resume(Unit)
            showCont = null
        }

        override fun onAdDisplayFailed(ad: InMobiInterstitial) {
            ads.remove(id)
            val failure = Errors.of("showFailed", "InMobi failed to display the ad")
            emit(
                AdEventMessage(
                    kind = AdEventKind.FAILED_TO_SHOW,
                    adId = id,
                    format = format,
                    errorCode = failure.code,
                    errorMessage = failure.message,
                ),
            )
            showCont?.takeIf { it.isActive }?.resumeWithException(failure)
            showCont = null
        }

        override fun onAdImpression(ad: InMobiInterstitial) = send(AdEventKind.IMPRESSION)

        override fun onAdClicked(ad: InMobiInterstitial, params: Map<Any, Any>) = send(AdEventKind.CLICKED)

        override fun onAdDismissed(ad: InMobiInterstitial) {
            ads.remove(id)
            send(AdEventKind.CLOSED)
        }

        override fun onRewardsUnlocked(ad: InMobiInterstitial, rewards: Map<Any, Any>) {
            val (type, amount) = Errors.firstReward(rewards)
            emit(
                AdEventMessage(
                    kind = AdEventKind.EARNED_REWARD,
                    adId = id,
                    format = format,
                    rewardAmount = amount,
                    rewardType = type,
                ),
            )
        }
    }

    // region FlutterPlugin / ActivityAware

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        events = InmobiEventsApi(binding.binaryMessenger)
        InmobiHostApi.setUp(binding.binaryMessenger, this)
        binding.platformViewRegistry.registerViewFactory(BANNER_VIEW_TYPE, InmobiBannerFactory(this))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        InmobiHostApi.setUp(binding.binaryMessenger, null)
        dispose()
        events = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityRef = WeakReference(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityRef = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityRef = WeakReference(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activityRef = null
    }

    // endregion

    internal fun emit(event: AdEventMessage) {
        mainHandler.post {
            val api = events ?: return@post
            CoroutineScope(Dispatchers.Main).launch { runCatching { api.onAdEvent(event) } }
        }
    }

    // region InmobiHostApi

    override suspend fun initialize(request: InitRequest) {
        val ctx = context ?: throw Errors.of("internal", "Plugin is not attached to an engine")
        if (request.appId.isBlank()) throw Errors.of("invalidConfig", "The InMobi account ID (appId) is empty")
        // InMobi test ads are configured per placement in the dashboard; debug
        // logging prints the device ID needed for "Selective" test mode.
        if (request.testMode) InMobiSdk.setLogLevel(InMobiSdk.LogLevel.DEBUG)
        if (initialized) return
        suspendCancellableCoroutine { cont ->
            InMobiSdk.init(
                ctx,
                request.appId,
                gdprJson(),
                object : SdkInitializationListener {
                    override fun onInitializationComplete(error: Error?) {
                        if (!cont.isActive) return
                        if (error == null) {
                            cont.resume(Unit)
                        } else {
                            cont.resumeWithException(
                                Errors.of("initializationFailed", error.message ?: "InMobi initialization failed"),
                            )
                        }
                    }
                },
            )
        }
        initialized = true
    }

    override suspend fun load(format: AdFormatMessage, adUnitId: String): String {
        if (format == AdFormatMessage.BANNER) {
            throw Errors.of("unsupportedFormat", "Banners load through the platform view")
        }
        val placementId = adUnitId.toLongOrNull()
            ?: throw Errors.of("invalidConfig", "InMobi placement IDs are numeric: '$adUnitId'")
        // InMobi needs an Activity context to show interstitials.
        val current = activity ?: throw Errors.of("noActivity", "No foreground Activity for the InMobi ad")
        val holder = Holder("inmobi-${++counter}", format)
        ads[holder.id] = holder
        return suspendCancellableCoroutine { cont ->
            holder.loadCont = cont
            val ad = InMobiInterstitial(current, placementId, holder)
            holder.ad = ad
            ad.load()
        }
    }

    override suspend fun show(adId: String) {
        val holder = ads[adId] ?: throw Errors.of("notReady", "No loaded InMobi ad with id $adId")
        val ad = holder.ad ?: throw Errors.of("notReady", "InMobi ad $adId was released")
        if (!ad.isReady()) throw Errors.of("notReady", "InMobi ad $adId is not ready")
        suspendCancellableCoroutine { cont ->
            holder.showCont = cont
            ad.show()
        }
    }

    override fun destroy(adId: String) {
        ads.remove(adId)?.ad = null
    }

    override fun applyConsent(consent: ConsentMessage) {
        this.consent = consent
        InMobiSdk.setIsAgeRestricted(consent.coppa)
        consent.ccpaOptOut?.let { InMobiPrivacyCompliance.setDoNotSell(it) }
        if (initialized) gdprJson()?.let { InMobiSdk.updateGDPRConsent(it) }
    }

    override fun dispose() {
        ads.values.forEach { it.ad = null }
        ads.clear()
    }

    // endregion

    /**
     * Explicit GDPR signals, if the app knows them. With a CMP (e.g. UMP) the
     * SDK reads the IAB TCF string itself (10.7.5+), so `null` is fine.
     */
    private fun gdprJson(): JSONObject? {
        val c = consent ?: return null
        if (c.gdprApplies == null && c.consentGiven == null) return null
        return JSONObject().apply {
            c.consentGiven?.let { put(InMobiSdk.IM_GDPR_CONSENT_AVAILABLE, it) }
            c.gdprApplies?.let { put(InMobiSdk.IM_GDPR_CONSENT_GDPR_APPLIES, if (it) "1" else "0") }
        }
    }
}
