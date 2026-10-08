package dev.arovyx.plugin.unifiedads.facebook

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.facebook.ads.Ad
import com.facebook.ads.AdError
import com.facebook.ads.AdSettings
import com.facebook.ads.AudienceNetworkAds
import com.facebook.ads.InterstitialAd
import com.facebook.ads.InterstitialAdListener
import com.facebook.ads.RewardedVideoAd
import com.facebook.ads.RewardedVideoAdListener
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

internal const val TAG = "UnifiedAdsFacebook"
internal const val BANNER_VIEW_TYPE = "dev.arovyx.plugin.unifiedads/facebook/banner"

/**
 * Facebook Audience Network (Meta) adapter plugin.
 *
 * Audience Network is bidding-only: this direct integration serves test ads
 * (test devices / `IMG_16_9_APP_INSTALL#` placements) but is not expected to
 * fill in production. API names are verified against SDK 6.22.0 (javap).
 */
class UnifiedAdsFacebookPlugin : FlutterPlugin, ActivityAware, FacebookHostApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var events: FacebookEventsApi? = null
    private var activityRef: WeakReference<Activity>? = null
    private var initialized = false
    private var counter = 0
    private val ads = mutableMapOf<String, Holder>()

    internal val activity: Activity? get() = activityRef?.get()

    private inner class Holder(val id: String, val format: AdFormatMessage) :
        InterstitialAdListener, RewardedVideoAdListener {
        var interstitial: InterstitialAd? = null
        var rewarded: RewardedVideoAd? = null
        var loadCont: CancellableContinuation<String>? = null
        var showCont: CancellableContinuation<Unit>? = null
        private var shown = false

        private fun send(kind: AdEventKind) = emit(AdEventMessage(kind, id, format))

        override fun onAdLoaded(ad: Ad) {
            send(AdEventKind.LOADED)
            loadCont?.takeIf { it.isActive }?.resume(id)
            loadCont = null
        }

        override fun onError(ad: Ad, error: AdError) {
            val load = loadCont
            if (load != null && load.isActive) {
                // Load failure.
                release()
                load.resumeWithException(Errors.load(error.errorCode, error.errorMessage))
                loadCont = null
                return
            }
            // Failure after loading = failure to show.
            val failure = Errors.show(error.errorCode, error.errorMessage)
            emit(
                AdEventMessage(
                    kind = AdEventKind.FAILED_TO_SHOW,
                    adId = id,
                    format = format,
                    errorCode = failure.code,
                    errorMessage = failure.message,
                    nativeCode = error.errorCode.toString(),
                ),
            )
            showCont?.takeIf { it.isActive }?.resumeWithException(failure)
            showCont = null
            release()
        }

        override fun onInterstitialDisplayed(ad: Ad) = displayed()

        override fun onLoggingImpression(ad: Ad) {
            // Rewarded video has no "displayed" callback: the impression marks the show.
            if (format == AdFormatMessage.REWARDED) displayed()
            send(AdEventKind.IMPRESSION)
        }

        private fun displayed() {
            if (shown) return
            shown = true
            send(AdEventKind.SHOWN)
            showCont?.takeIf { it.isActive }?.resume(Unit)
            showCont = null
        }

        override fun onAdClicked(ad: Ad) = send(AdEventKind.CLICKED)

        override fun onInterstitialDismissed(ad: Ad) = closed()

        override fun onRewardedVideoCompleted() {
            // Audience Network reports completion without an amount/type; Dart
            // fills in the configured default.
            send(AdEventKind.EARNED_REWARD)
        }

        override fun onRewardedVideoClosed() = closed()

        private fun closed() {
            send(AdEventKind.CLOSED)
            release()
        }

        fun release() {
            ads.remove(id)
            interstitial?.destroy()
            rewarded?.destroy()
            interstitial = null
            rewarded = null
        }
    }

    // region FlutterPlugin / ActivityAware

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        events = FacebookEventsApi(binding.binaryMessenger)
        FacebookHostApi.setUp(binding.binaryMessenger, this)
        binding.platformViewRegistry.registerViewFactory(BANNER_VIEW_TYPE, FacebookBannerFactory(this))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        FacebookHostApi.setUp(binding.binaryMessenger, null)
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

    // region FacebookHostApi

    override suspend fun initialize(request: InitRequest) {
        val ctx = context ?: throw Errors.of("internal", "Plugin is not attached to an engine")
        // Hashed device IDs (printed by the SDK in logcat) receive test ads.
        if (request.testMode && request.testDeviceIds.isNotEmpty()) {
            AdSettings.addTestDevices(request.testDeviceIds)
        }
        if (request.testMode) {
            Log.i(TAG, "Test mode: use registered test devices or IMG_16_9_APP_INSTALL#<placement> IDs.")
        }
        if (initialized) return
        suspendCancellableCoroutine { cont ->
            AudienceNetworkAds.buildInitSettings(ctx)
                .withInitListener { result ->
                    mainHandler.post {
                        if (!cont.isActive) return@post
                        if (result.isSuccess) {
                            cont.resume(Unit)
                        } else {
                            cont.resumeWithException(
                                Errors.of("initializationFailed", result.message ?: "Audience Network init failed"),
                            )
                        }
                    }
                }
                .initialize()
        }
        initialized = true
    }

    override suspend fun load(format: AdFormatMessage, adUnitId: String): String {
        if (format == AdFormatMessage.BANNER) {
            throw Errors.of("unsupportedFormat", "Banners load through the platform view")
        }
        val ctx = activity ?: context ?: throw Errors.of("internal", "Plugin is not attached")
        val holder = Holder("facebook-${++counter}", format)
        ads[holder.id] = holder
        return suspendCancellableCoroutine { cont ->
            holder.loadCont = cont
            if (format == AdFormatMessage.REWARDED) {
                val ad = RewardedVideoAd(ctx, adUnitId)
                holder.rewarded = ad
                ad.loadAd(ad.buildLoadAdConfig().withAdListener(holder).build())
            } else {
                val ad = InterstitialAd(ctx, adUnitId)
                holder.interstitial = ad
                ad.loadAd(ad.buildLoadAdConfig().withAdListener(holder).build())
            }
        }
    }

    override suspend fun show(adId: String) {
        val holder = ads[adId] ?: throw Errors.of("notReady", "No loaded Audience Network ad with id $adId")
        val interstitial = holder.interstitial
        val rewarded = holder.rewarded
        if (interstitial?.isAdInvalidated == true || rewarded?.isAdInvalidated == true) {
            holder.release()
            throw Errors.of("notReady", "Audience Network ad $adId expired")
        }
        suspendCancellableCoroutine { cont ->
            holder.showCont = cont
            val accepted = interstitial?.show() ?: rewarded?.show() ?: false
            if (!accepted && cont.isActive) {
                holder.showCont = null
                holder.release()
                cont.resumeWithException(Errors.of("showFailed", "Audience Network refused to show the ad"))
            }
        }
    }

    override fun destroy(adId: String) {
        ads[adId]?.release()
    }

    override fun applyConsent(consent: ConsentMessage) {
        // US privacy (Limited Data Use); country/state 0 = geolocate.
        when (consent.ccpaOptOut) {
            true -> AdSettings.setDataProcessingOptions(arrayOf("LDU"), 0, 0)
            false -> AdSettings.setDataProcessingOptions(arrayOf())
            null -> Unit
        }
        // Child-directed / mixed audience.
        AdSettings.setMixedAudience(consent.coppa)
    }

    override fun dispose() {
        ads.values.toList().forEach { it.release() }
        ads.clear()
    }

    // endregion
}
