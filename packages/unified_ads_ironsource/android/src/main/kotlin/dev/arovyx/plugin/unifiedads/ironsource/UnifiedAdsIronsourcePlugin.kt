package dev.arovyx.plugin.unifiedads.ironsource

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.unity3d.mediation.LevelPlay
import com.unity3d.mediation.LevelPlayAdError
import com.unity3d.mediation.LevelPlayAdInfo
import com.unity3d.mediation.LevelPlayConfiguration
import com.unity3d.mediation.LevelPlayInitError
import com.unity3d.mediation.LevelPlayInitListener
import com.unity3d.mediation.LevelPlayInitRequest
import com.unity3d.mediation.LevelPlayPrivacySettings
import com.unity3d.mediation.interstitial.LevelPlayInterstitialAd
import com.unity3d.mediation.interstitial.LevelPlayInterstitialAdListener
import com.unity3d.mediation.rewarded.LevelPlayReward
import com.unity3d.mediation.rewarded.LevelPlayRewardedAd
import com.unity3d.mediation.rewarded.LevelPlayRewardedAdListener
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

internal const val TAG = "UnifiedAdsLevelPlay"

/** LevelPlay metadata read by its Meta adapter (matched case-insensitively). */
private const val META_MIXED_AUDIENCE = "Meta_Mixed_Audience"
internal const val BANNER_VIEW_TYPE = "dev.arovyx.plugin.unifiedads/ironsource/banner"

/** ironSource / Unity LevelPlay adapter plugin (LevelPlay 9.x ad-unit APIs only). */
class UnifiedAdsIronsourcePlugin : FlutterPlugin, ActivityAware, IronsourceHostApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var events: IronsourceEventsApi? = null
    private var activityRef: WeakReference<Activity>? = null
    private var initialized = false
    private var counter = 0
    private val ads = mutableMapOf<String, Holder>()

    internal val activity: Activity? get() = activityRef?.get()

    private inner class Holder(val id: String, val format: AdFormatMessage) :
        LevelPlayInterstitialAdListener, LevelPlayRewardedAdListener {
        var interstitial: LevelPlayInterstitialAd? = null
        var rewarded: LevelPlayRewardedAd? = null
        var loadCont: CancellableContinuation<String>? = null
        var showCont: CancellableContinuation<Unit>? = null

        private fun send(kind: AdEventKind) = emit(AdEventMessage(kind, id, format))

        override fun onAdLoaded(adInfo: LevelPlayAdInfo) {
            send(AdEventKind.LOADED)
            loadCont?.takeIf { it.isActive }?.resume(id)
            loadCont = null
        }

        override fun onAdLoadFailed(error: LevelPlayAdError) {
            release()
            loadCont?.takeIf { it.isActive }?.resumeWithException(Errors.load(error.errorCode, error.errorMessage))
            loadCont = null
        }

        override fun onAdDisplayed(adInfo: LevelPlayAdInfo) {
            send(AdEventKind.SHOWN)
            // LevelPlay has no separate fullscreen impression callback.
            send(AdEventKind.IMPRESSION)
            showCont?.takeIf { it.isActive }?.resume(Unit)
            showCont = null
        }

        override fun onAdDisplayFailed(error: LevelPlayAdError, adInfo: LevelPlayAdInfo) {
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

        override fun onAdClicked(adInfo: LevelPlayAdInfo) = send(AdEventKind.CLICKED)

        override fun onAdInfoChanged(adInfo: LevelPlayAdInfo) = Unit

        override fun onAdClosed(adInfo: LevelPlayAdInfo) {
            send(AdEventKind.CLOSED)
            release()
        }

        /** May arrive after [onAdClosed]; the Dart side accepts a late reward. */
        override fun onAdRewarded(reward: LevelPlayReward, adInfo: LevelPlayAdInfo) {
            emit(
                AdEventMessage(
                    kind = AdEventKind.EARNED_REWARD,
                    adId = id,
                    format = format,
                    rewardAmount = reward.amount.toDouble(),
                    rewardType = reward.name,
                ),
            )
        }

        fun release() {
            ads.remove(id)
            interstitial = null
            rewarded = null
        }
    }

    // region FlutterPlugin / ActivityAware

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        events = IronsourceEventsApi(binding.binaryMessenger)
        IronsourceHostApi.setUp(binding.binaryMessenger, this)
        binding.platformViewRegistry.registerViewFactory(BANNER_VIEW_TYPE, IronsourceBannerFactory(this))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        IronsourceHostApi.setUp(binding.binaryMessenger, null)
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

    // region IronsourceHostApi

    override suspend fun initialize(request: InitRequest): InitInfo {
        val ctx = activity ?: context ?: throw Errors.of("internal", "Plugin is not attached to an engine")
        if (request.appId.isBlank()) throw Errors.of("invalidConfig", "The LevelPlay app key (appId) is empty")
        if (request.testMode) {
            Log.i(TAG, "LevelPlay has no test-ads flag: use the LevelPlay test suite or dashboard test devices.")
        }
        val metaAdapter = MetaBidding.detect()
        if (initialized) return InitInfo(metaAdapter)
        val builder = LevelPlayInitRequest.Builder(request.appId)
        request.userId?.let { builder.withUserId(it) }
        suspendCancellableCoroutine { cont ->
            LevelPlay.init(
                ctx,
                builder.build(),
                object : LevelPlayInitListener {
                    override fun onInitSuccess(configuration: LevelPlayConfiguration) {
                        if (cont.isActive) cont.resume(Unit)
                    }

                    override fun onInitFailed(error: LevelPlayInitError) {
                        if (cont.isActive) {
                            cont.resumeWithException(
                                FlutterError(
                                    "initializationFailed",
                                    error.errorMessage,
                                    error.errorCode.toString(),
                                ),
                            )
                        }
                    }
                },
            )
        }
        initialized = true
        return InitInfo(metaAdapter)
    }

    override suspend fun load(format: AdFormatMessage, adUnitId: String): String {
        if (!initialized) throw Errors.of("notInitialized", "LevelPlay is not initialized")
        val holder = Holder("ironsource-${++counter}", format)
        ads[holder.id] = holder
        return suspendCancellableCoroutine { cont ->
            holder.loadCont = cont
            when (format) {
                AdFormatMessage.INTERSTITIAL -> {
                    val ad = LevelPlayInterstitialAd(adUnitId)
                    holder.interstitial = ad
                    ad.setListener(holder)
                    ad.loadAd()
                }
                AdFormatMessage.REWARDED -> {
                    val ad = LevelPlayRewardedAd(adUnitId)
                    holder.rewarded = ad
                    ad.setListener(holder)
                    ad.loadAd()
                }
                AdFormatMessage.BANNER -> {
                    ads.remove(holder.id)
                    cont.resumeWithException(Errors.of("unsupportedFormat", "Banners load through the platform view"))
                }
            }
        }
    }

    override suspend fun show(adId: String) {
        val holder = ads[adId] ?: throw Errors.of("notReady", "No loaded LevelPlay ad with id $adId")
        val current = activity ?: throw Errors.of("noActivity", "No foreground Activity to show the ad")
        suspendCancellableCoroutine { cont ->
            holder.showCont = cont
            holder.interstitial?.showAd(current)
            holder.rewarded?.showAd(current)
        }
    }

    override fun destroy(adId: String) {
        ads[adId]?.release()
    }

    override fun applyConsent(consent: ConsentMessage) {
        // LevelPlay expects these before init; UMP / IAB TCF strings are also read automatically.
        consent.consentGiven?.let { LevelPlayPrivacySettings.setGDPRConsent(it) }
        consent.ccpaOptOut?.let { LevelPlayPrivacySettings.setCCPA(it) }
        LevelPlayPrivacySettings.setCOPPA(consent.coppa)
        // Opt-in Meta bidding: privacy reaches Audience Network before LevelPlay
        // initializes the adapter (consent is applied before init).
        if (MetaBidding.detect() != null) {
            MetaBidding.applyPrivacy(consent.ccpaOptOut, consent.coppa)
            LevelPlay.setMetaData(META_MIXED_AUDIENCE, consent.coppa.toString())
        }
    }

    override fun dispose() {
        ads.values.toList().forEach { it.release() }
        ads.clear()
    }

    // endregion
}
