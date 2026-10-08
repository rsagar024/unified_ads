package dev.arovyx.plugin.unifiedads.startapp

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.startapp.sdk.adsbase.Ad
import com.startapp.sdk.adsbase.StartAppAd
import com.startapp.sdk.adsbase.StartAppSDK
import com.startapp.sdk.adsbase.adlisteners.AdDisplayListener
import com.startapp.sdk.adsbase.adlisteners.AdEventListener
import com.startapp.sdk.adsbase.adlisteners.VideoListener
import com.startapp.sdk.adsbase.model.AdPreferences
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

internal const val BANNER_VIEW_TYPE = "dev.arovyx.plugin.unifiedads/startapp/banner"

/**
 * Start.io adapter plugin. Start.io is keyed by its App ID only; an ad-unit
 * ID, when given, is sent as the ad tag. Splash and return ads (shown
 * automatically by the SDK by default) are disabled.
 */
class UnifiedAdsStartappPlugin : FlutterPlugin, ActivityAware, StartappHostApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var events: StartappEventsApi? = null
    private var activityRef: WeakReference<Activity>? = null
    private var initialized = false
    private var counter = 0
    private val ads = mutableMapOf<String, Holder>()

    internal val activity: Activity? get() = activityRef?.get()

    private inner class Holder(val id: String, val format: AdFormatMessage, val ad: StartAppAd) {
        var showCont: CancellableContinuation<Unit>? = null

        fun send(kind: AdEventKind) = emit(AdEventMessage(kind, id, format))
    }

    // region FlutterPlugin / ActivityAware

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        events = StartappEventsApi(binding.binaryMessenger)
        StartappHostApi.setUp(binding.binaryMessenger, this)
        binding.platformViewRegistry.registerViewFactory(BANNER_VIEW_TYPE, StartappBannerFactory(this))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        StartappHostApi.setUp(binding.binaryMessenger, null)
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

    /** Ad preferences carrying [adTag] (the per-format "ad-unit ID", if any). */
    internal fun preferences(adTag: String?): AdPreferences {
        val preferences = AdPreferences()
        if (!adTag.isNullOrBlank()) preferences.setAdTag(adTag)
        return preferences
    }

    // region StartappHostApi

    override suspend fun initialize(request: InitRequest) {
        val ctx = context ?: throw Errors.of("internal", "Plugin is not attached to an engine")
        if (request.appId.isBlank()) throw Errors.of("invalidConfig", "The Start.io App ID (appId) is empty")
        StartAppSDK.setTestAdsEnabled(request.testMode)
        if (initialized) return
        suspendCancellableCoroutine { cont ->
            StartAppSDK.initParams(ctx, request.appId)
                .setReturnAdsEnabled(false)
                .setCallback { mainHandler.post { if (cont.isActive) cont.resume(Unit) } }
                .init()
        }
        StartAppAd.disableSplash()
        initialized = true
    }

    override suspend fun load(format: AdFormatMessage, adUnitId: String): String {
        if (format == AdFormatMessage.BANNER) {
            throw Errors.of("unsupportedFormat", "Banners load through the platform view")
        }
        val ctx = activity ?: context ?: throw Errors.of("internal", "Plugin is not attached")
        val holder = Holder("startapp-${++counter}", format, StartAppAd(ctx))
        val mode = if (format == AdFormatMessage.REWARDED) {
            StartAppAd.AdMode.REWARDED_VIDEO
        } else {
            StartAppAd.AdMode.AUTOMATIC
        }
        if (format == AdFormatMessage.REWARDED) {
            // Start.io reports no amount/type; Dart fills in the configured default.
            holder.ad.setVideoListener(VideoListener { holder.send(AdEventKind.EARNED_REWARD) })
        }
        suspendCancellableCoroutine { cont ->
            holder.ad.loadAd(
                mode,
                preferences(adUnitId),
                object : AdEventListener {
                    override fun onReceiveAd(ad: Ad) {
                        if (cont.isActive) cont.resume(Unit)
                    }

                    override fun onFailedToReceiveAd(ad: Ad?) {
                        if (cont.isActive) {
                            cont.resumeWithException(Errors.of("noFill", ad?.errorMessage ?: "Start.io returned no ad"))
                        }
                    }
                },
            )
        }
        ads[holder.id] = holder
        holder.send(AdEventKind.LOADED)
        return holder.id
    }

    override suspend fun show(adId: String) {
        val holder = ads[adId] ?: throw Errors.of("notReady", "No loaded Start.io ad with id $adId")
        if (!holder.ad.isReady) throw Errors.of("notReady", "Start.io ad $adId is not ready")
        suspendCancellableCoroutine { cont ->
            holder.showCont = cont
            val accepted = holder.ad.showAd(
                object : AdDisplayListener {
                    override fun adDisplayed(ad: Ad) {
                        holder.send(AdEventKind.SHOWN)
                        // Start.io has no separate fullscreen impression callback.
                        holder.send(AdEventKind.IMPRESSION)
                        holder.showCont?.takeIf { it.isActive }?.resume(Unit)
                        holder.showCont = null
                    }

                    override fun adHidden(ad: Ad) {
                        ads.remove(holder.id)
                        holder.send(AdEventKind.CLOSED)
                    }

                    override fun adClicked(ad: Ad) = holder.send(AdEventKind.CLICKED)

                    override fun adNotDisplayed(ad: Ad) = notDisplayed(holder)
                },
            )
            if (!accepted) notDisplayed(holder)
        }
    }

    private fun notDisplayed(holder: Holder) {
        if (ads.remove(holder.id) == null && holder.showCont == null) return
        val failure = Errors.of("showFailed", "Start.io did not display the ad")
        emit(
            AdEventMessage(
                kind = AdEventKind.FAILED_TO_SHOW,
                adId = holder.id,
                format = holder.format,
                errorCode = failure.code,
                errorMessage = failure.message,
            ),
        )
        holder.showCont?.takeIf { it.isActive }?.resumeWithException(failure)
        holder.showCont = null
    }

    override fun destroy(adId: String) {
        ads.remove(adId)
    }

    override fun applyConsent(consent: ConsentMessage) {
        val ctx = context ?: return
        consent.consentGiven?.let {
            StartAppSDK.setUserConsent(ctx, "pas", System.currentTimeMillis(), it)
        }
        consent.ccpaOptOut?.let {
            // IAB US Privacy string: version 1, notice given, opt-out Y/N, LSPA not covered.
            StartAppSDK.getExtras(ctx).edit()
                .putString("IABUSPrivacy_String", if (it) "1YYN" else "1YNN")
                .apply()
        }
        // COPPA is declared through manifest meta-data (see docs/setup/startapp.md).
    }

    override fun dispose() {
        ads.clear()
    }

    // endregion
}
