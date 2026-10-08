package dev.arovyx.plugin.unifiedads.unity

import android.app.Activity
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import com.unity3d.ads.InitializationConfiguration
import com.unity3d.ads.InitializationListener
import com.unity3d.ads.InterstitialAd
import com.unity3d.ads.InterstitialShowListener
import com.unity3d.ads.LoadConfiguration
import com.unity3d.ads.LoadListener
import com.unity3d.ads.RewardedAd
import com.unity3d.ads.RewardedShowListener
import com.unity3d.ads.ShowConfiguration
import com.unity3d.ads.ShowFinishState
import com.unity3d.ads.UnityAds
import com.unity3d.ads.UnityAdsError
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

internal const val BANNER_VIEW_TYPE = "dev.arovyx.plugin.unifiedads/unity/banner"

/**
 * Unity Ads adapter plugin, built only on the instance APIs introduced in
 * 4.19 (`InterstitialAd`, `RewardedAd`, `BannerAd`); the deprecated static
 * API is not used.
 */
class UnifiedAdsUnityPlugin : FlutterPlugin, ActivityAware, UnityHostApi {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var events: UnityEventsApi? = null
    private var activityRef: WeakReference<Activity>? = null
    private var appContext: Context? = null
    private var initialized = false
    private var initRunning = false
    private val initWaiters = mutableListOf<(UnityAdsError?) -> Unit>()
    private var counter = 0
    private val ads = mutableMapOf<String, Holder>()

    internal val activity: Activity? get() = activityRef?.get()

    private inner class Holder(val id: String, val format: AdFormatMessage) {
        var interstitial: InterstitialAd? = null
        var rewarded: RewardedAd? = null
        var showCont: CancellableContinuation<Unit>? = null

        fun send(kind: AdEventKind) = emit(AdEventMessage(kind, id, format))

        fun started() {
            send(AdEventKind.SHOWN)
            send(AdEventKind.IMPRESSION)
            showCont?.takeIf { it.isActive }?.resume(Unit)
            showCont = null
        }

        fun completed() {
            send(AdEventKind.CLOSED)
            release()
        }

        fun failed(error: UnityAdsError) {
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

        fun release() {
            ads.remove(id)
            interstitial = null
            rewarded = null
        }
    }

    // region FlutterPlugin / ActivityAware

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        events = UnityEventsApi(binding.binaryMessenger)
        UnityHostApi.setUp(binding.binaryMessenger, this)
        binding.platformViewRegistry.registerViewFactory(BANNER_VIEW_TYPE, UnityBannerFactory(this))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        UnityHostApi.setUp(binding.binaryMessenger, null)
        dispose()
        events = null
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

    // region UnityHostApi

    override suspend fun initialize(request: InitRequest) {
        if (request.appId.isBlank()) throw Errors.of("invalidConfig", "The Unity Game ID (appId) is empty")
        if (initialized) return
        // Unity must download its game configuration before it reports
        // completion; offline, the SDK waits for connectivity and never calls
        // back. Start it anyway (it finishes by itself once online, so a later
        // init call succeeds at once) but fail fast instead of timing out.
        startInitialization(request)
        if (!isOnline()) {
            throw Errors.of(
                "networkError",
                "No internet connection: Unity Ads must download its configuration to " +
                    "initialize. It completes automatically once the device is online; " +
                    "call UnifiedAds.init again after reconnecting.",
            )
        }
        suspendCancellableCoroutine { cont ->
            val waiter: (UnityAdsError?) -> Unit = { error ->
                if (cont.isActive) {
                    if (error == null) {
                        cont.resume(Unit)
                    } else {
                        cont.resumeWithException(Errors.init(error.code, error.message))
                    }
                }
            }
            initWaiters += waiter
            cont.invokeOnCancellation { mainHandler.post { initWaiters.remove(waiter) } }
        }
    }

    /** Starts one native initialization; concurrent init calls share it. */
    private fun startInitialization(request: InitRequest) {
        if (initRunning) return
        initRunning = true
        val configuration = InitializationConfiguration.Builder(request.appId)
            .withTestMode(request.testMode)
            .build()
        UnityAds.initialize(
            configuration,
            object : InitializationListener {
                override fun onInitializationComplete(error: UnityAdsError?) {
                    mainHandler.post {
                        initRunning = false
                        if (error == null) initialized = true
                        val waiters = initWaiters.toList()
                        initWaiters.clear()
                        waiters.forEach { it(error) }
                    }
                }
            },
        )
    }

    /** Whether the device has a network with internet access (true if unknown). */
    private fun isOnline(): Boolean = runCatching {
        val manager = appContext?.getSystemService(ConnectivityManager::class.java) ?: return true
        val capabilities = manager.getNetworkCapabilities(manager.activeNetwork) ?: return false
        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }.getOrDefault(true)

    override suspend fun load(format: AdFormatMessage, adUnitId: String): String {
        if (format == AdFormatMessage.BANNER) {
            throw Errors.of("unsupportedFormat", "Banners load through the platform view")
        }
        val holder = Holder("unity-${++counter}", format)
        val configuration = LoadConfiguration.Builder(adUnitId).build()
        suspendCancellableCoroutine { cont ->
            if (format == AdFormatMessage.REWARDED) {
                RewardedAd.load(
                    configuration,
                    object : LoadListener<RewardedAd> {
                        override fun onAdLoaded(ad: RewardedAd?, error: UnityAdsError?) {
                            holder.rewarded = ad
                            finishLoad(cont, ad != null, error)
                        }
                    },
                )
            } else {
                InterstitialAd.load(
                    configuration,
                    object : LoadListener<InterstitialAd> {
                        override fun onAdLoaded(ad: InterstitialAd?, error: UnityAdsError?) {
                            holder.interstitial = ad
                            finishLoad(cont, ad != null, error)
                        }
                    },
                )
            }
        }
        ads[holder.id] = holder
        holder.send(AdEventKind.LOADED)
        return holder.id
    }

    private fun finishLoad(cont: CancellableContinuation<Unit>, loaded: Boolean, error: UnityAdsError?) {
        if (!cont.isActive) return
        if (loaded) {
            cont.resume(Unit)
        } else {
            cont.resumeWithException(
                Errors.load(error?.code ?: Errors.NO_FILL, error?.message ?: "Unity Ads load failed"),
            )
        }
    }

    override suspend fun show(adId: String) {
        val holder = ads[adId] ?: throw Errors.of("notReady", "No loaded Unity ad with id $adId")
        val current = activity ?: throw Errors.of("noActivity", "No foreground Activity to show the ad")
        val showConfiguration = ShowConfiguration.Builder().build()
        suspendCancellableCoroutine { cont ->
            holder.showCont = cont
            holder.interstitial?.show(
                current,
                showConfiguration,
                object : InterstitialShowListener {
                    override fun onStarted(ad: InterstitialAd) = holder.started()

                    override fun onClicked(ad: InterstitialAd) = holder.send(AdEventKind.CLICKED)

                    override fun onCompleted(ad: InterstitialAd, state: ShowFinishState) = holder.completed()

                    override fun onFailed(ad: InterstitialAd, error: UnityAdsError) = holder.failed(error)
                },
            )
            holder.rewarded?.show(
                current,
                showConfiguration,
                object : RewardedShowListener {
                    override fun onStarted(ad: RewardedAd) = holder.started()

                    override fun onClicked(ad: RewardedAd) = holder.send(AdEventKind.CLICKED)

                    // Unity reports no amount/type; Dart fills in the configured default.
                    override fun onRewarded(ad: RewardedAd) = holder.send(AdEventKind.EARNED_REWARD)

                    override fun onCompleted(ad: RewardedAd, state: ShowFinishState) = holder.completed()

                    override fun onFailed(ad: RewardedAd, error: UnityAdsError) = holder.failed(error)
                },
            )
        }
    }

    override fun destroy(adId: String) {
        ads[adId]?.release()
    }

    override fun applyConsent(consent: ConsentMessage) {
        // Unity requires these before (or during) initialization.
        consent.consentGiven?.let { UnityAds.userConsent = it }
        consent.ccpaOptOut?.let { UnityAds.userOptOut = it }
        UnityAds.nonBehavioral = consent.coppa
    }

    override fun dispose() {
        ads.values.toList().forEach { it.release() }
        ads.clear()
    }

    // endregion
}
