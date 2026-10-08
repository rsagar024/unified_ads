package dev.arovyx.plugin.unifiedads.applovin

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdListener
import com.applovin.mediation.MaxAdRevenueListener
import com.applovin.mediation.MaxError
import com.applovin.mediation.MaxReward
import com.applovin.mediation.MaxRewardedAdListener
import com.applovin.mediation.ads.MaxAppOpenAd
import com.applovin.mediation.ads.MaxInterstitialAd
import com.applovin.mediation.ads.MaxRewardedAd
import com.applovin.sdk.AppLovinMediationProvider
import com.applovin.sdk.AppLovinPrivacySettings
import com.applovin.sdk.AppLovinSdk
import com.applovin.sdk.AppLovinSdkInitializationConfiguration
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

internal const val BANNER_VIEW_TYPE = "dev.arovyx.plugin.unifiedads/applovin/banner"

/**
 * AppLovin MAX adapter plugin. Uses the context-free MAX APIs (13.3+); the
 * Activity is only passed when showing.
 */
class UnifiedAdsApplovinPlugin : FlutterPlugin, ActivityAware, ApplovinHostApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var events: ApplovinEventsApi? = null
    private var activityRef: WeakReference<Activity>? = null
    private var initialized = false
    private var coppa = false
    private var counter = 0
    private val ads = mutableMapOf<String, Holder>()

    /** MAX rewarded ads are singletons per ad unit: the holder currently bound to each unit. */
    private val rewardedByUnit = mutableMapOf<String, Holder>()

    internal val activity: Activity? get() = activityRef?.get()

    private inner class Holder(val id: String, val format: AdFormatMessage, val adUnitId: String) :
        MaxRewardedAdListener, MaxAdRevenueListener {
        var interstitial: MaxInterstitialAd? = null
        var rewarded: MaxRewardedAd? = null
        var appOpen: MaxAppOpenAd? = null
        var loadCont: CancellableContinuation<String>? = null
        var showCont: CancellableContinuation<Unit>? = null

        private fun send(kind: AdEventKind) = emit(AdEventMessage(kind, id, format))

        override fun onAdLoaded(ad: MaxAd) {
            send(AdEventKind.LOADED)
            loadCont?.takeIf { it.isActive }?.resume(id)
            loadCont = null
        }

        override fun onAdLoadFailed(adUnitId: String, error: MaxError) {
            release()
            loadCont?.takeIf { it.isActive }?.resumeWithException(Errors.load(error.code, error.message))
            loadCont = null
        }

        override fun onAdDisplayed(ad: MaxAd) {
            send(AdEventKind.SHOWN)
            showCont?.takeIf { it.isActive }?.resume(Unit)
            showCont = null
        }

        override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) {
            val failure = Errors.show(error.code, error.message)
            emit(
                AdEventMessage(
                    kind = AdEventKind.FAILED_TO_SHOW,
                    adId = id,
                    format = format,
                    errorCode = failure.code,
                    errorMessage = failure.message,
                    nativeCode = error.code.toString(),
                ),
            )
            showCont?.takeIf { it.isActive }?.resumeWithException(failure)
            showCont = null
            release()
        }

        override fun onAdClicked(ad: MaxAd) = send(AdEventKind.CLICKED)

        override fun onAdHidden(ad: MaxAd) {
            send(AdEventKind.CLOSED)
            release()
        }

        override fun onUserRewarded(ad: MaxAd, reward: MaxReward) {
            emit(
                AdEventMessage(
                    kind = AdEventKind.EARNED_REWARD,
                    adId = id,
                    format = format,
                    rewardAmount = reward.amount.toDouble(),
                    rewardType = reward.label,
                ),
            )
        }

        /** MAX reports revenue once per impression: used as the impression event. */
        override fun onAdRevenuePaid(ad: MaxAd) = send(AdEventKind.IMPRESSION)

        fun release() {
            ads.remove(id)
            interstitial?.let {
                it.setListener(null)
                it.setRevenueListener(null)
                it.destroy()
            }
            interstitial = null
            appOpen?.let {
                it.setListener(null)
                it.setRevenueListener(null)
                it.destroy()
            }
            appOpen = null
            // The rewarded singleton is kept alive; only unbind this holder.
            if (rewardedByUnit[adUnitId] === this) rewardedByUnit.remove(adUnitId)
            rewarded = null
        }
    }

    // region FlutterPlugin / ActivityAware

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        events = ApplovinEventsApi(binding.binaryMessenger)
        ApplovinHostApi.setUp(binding.binaryMessenger, this)
        binding.platformViewRegistry.registerViewFactory(BANNER_VIEW_TYPE, ApplovinBannerFactory(this))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ApplovinHostApi.setUp(binding.binaryMessenger, null)
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

    // region ApplovinHostApi

    override suspend fun initialize(request: InitRequest): InitInfo {
        val ctx = context ?: throw Errors.of("internal", "Plugin is not attached to an engine")
        if (request.appId.isBlank()) throw Errors.of("invalidConfig", "The AppLovin MAX SDK key (appId) is empty")
        if (coppa) {
            throw Errors.of("configConflict", "AppLovin MAX must not be initialized for child-directed users")
        }
        val metaAdapter = MetaBidding.detect()
        if (initialized) return InitInfo(metaAdapter)
        val configuration = AppLovinSdkInitializationConfiguration.builder(request.appId)
            .setMediationProvider(AppLovinMediationProvider.MAX)
            .setTestDeviceAdvertisingIds(if (request.testMode) request.testDeviceIds else emptyList())
            .build()
        suspendCancellableCoroutine { cont ->
            AppLovinSdk.getInstance(ctx).initialize(configuration) {
                if (cont.isActive) cont.resume(Unit)
            }
        }
        initialized = true
        return InitInfo(metaAdapter)
    }

    override suspend fun load(format: AdFormatMessage, adUnitId: String): String {
        val holder = Holder("applovin-${++counter}", format, adUnitId)
        ads[holder.id] = holder
        return suspendCancellableCoroutine { cont ->
            holder.loadCont = cont
            when (format) {
                AdFormatMessage.INTERSTITIAL -> {
                    val ad = MaxInterstitialAd(adUnitId)
                    holder.interstitial = ad
                    ad.setListener(holder)
                    ad.setRevenueListener(holder)
                    ad.loadAd()
                }
                AdFormatMessage.REWARDED -> {
                    val ad = MaxRewardedAd.getInstance(adUnitId)
                    // A newer load for the same unit takes over the singleton.
                    rewardedByUnit.put(adUnitId, holder)?.let { ads.remove(it.id) }
                    holder.rewarded = ad
                    ad.setListener(holder)
                    ad.setRevenueListener(holder)
                    ad.loadAd()
                }
                AdFormatMessage.APP_OPEN -> {
                    val ad = MaxAppOpenAd(adUnitId)
                    holder.appOpen = ad
                    ad.setListener(holder)
                    ad.setRevenueListener(holder)
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
        val holder = ads[adId] ?: throw Errors.of("notReady", "No loaded AppLovin ad with id $adId")
        val current = activity ?: throw Errors.of("noActivity", "No foreground Activity to show the ad")
        suspendCancellableCoroutine { cont ->
            holder.showCont = cont
            holder.interstitial?.showAd(current)
            holder.rewarded?.showAd(current)
            holder.appOpen?.showAd()
        }
    }

    override fun destroy(adId: String) {
        ads[adId]?.release()
    }

    override fun applyConsent(consent: ConsentMessage) {
        coppa = consent.coppa
        // Opt-in Meta bidding: privacy reaches Audience Network before MAX
        // initializes the adapter (consent is applied before init).
        if (MetaBidding.detect() != null) MetaBidding.applyPrivacy(consent.ccpaOptOut, consent.coppa)
        // MAX requires these before initialization; later calls still update the flags.
        consent.consentGiven?.let { AppLovinPrivacySettings.setHasUserConsent(it) }
        consent.ccpaOptOut?.let { AppLovinPrivacySettings.setDoNotSell(it) }
    }

    override fun dispose() {
        ads.values.toList().forEach { it.release() }
        ads.clear()
        rewardedByUnit.clear()
    }

    // endregion
}
