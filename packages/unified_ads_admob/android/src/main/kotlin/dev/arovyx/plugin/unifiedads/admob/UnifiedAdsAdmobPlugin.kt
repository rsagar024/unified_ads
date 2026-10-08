package dev.arovyx.plugin.unifiedads.admob

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.libraries.ads.mobile.sdk.MobileAds
import com.google.android.libraries.ads.mobile.sdk.common.AdRequest
import com.google.android.libraries.ads.mobile.sdk.common.AgeRestrictedTreatment
import com.google.android.libraries.ads.mobile.sdk.common.RequestConfiguration
import com.google.android.libraries.ads.mobile.sdk.initialization.InitializationConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import java.lang.ref.WeakReference
import kotlin.coroutines.resume
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine

internal const val TAG = "UnifiedAdsAdmob"
private const val APP_ID_KEY = "com.google.android.gms.ads.APPLICATION_ID"

/** Sends events to Dart. */
internal fun interface AdEventEmitter {
    fun emit(event: AdEventMessage)
}

/**
 * AdMob adapter plugin: Pigeon host API, platform-view factory for banners and
 * Activity tracking for full-screen ads and the UMP consent form.
 */
class UnifiedAdsAdmobPlugin : FlutterPlugin, ActivityAware, AdmobHostApi, AdEventEmitter {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var messenger: BinaryMessenger? = null
    private var events: AdmobEventsApi? = null
    private var activityRef: WeakReference<Activity>? = null
    private val fullScreen = FullScreenAds(this)

    private var initialized = false
    private var testDeviceIds: List<String> = emptyList()
    private var coppa = false

    internal val activity: Activity? get() = activityRef?.get()

    // region FlutterPlugin / ActivityAware

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        messenger = binding.binaryMessenger
        events = AdmobEventsApi(binding.binaryMessenger)
        AdmobHostApi.setUp(binding.binaryMessenger, this)
        binding.platformViewRegistry.registerViewFactory(BANNER_VIEW_TYPE, AdmobBannerFactory(this))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AdmobHostApi.setUp(binding.binaryMessenger, null)
        fullScreen.clear()
        events = null
        messenger = null
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

    /** Posts [event] to Dart on the main thread. Delivery failures are ignored. */
    override fun emit(event: AdEventMessage) {
        mainHandler.post {
            val api = events ?: return@post
            CoroutineScope(Dispatchers.Main).launch {
                runCatching { api.onAdEvent(event) }
            }
        }
    }

    internal fun buildRequest(adUnitId: String): AdRequest = AdRequest.Builder(adUnitId).build()

    // region AdmobHostApi

    override suspend fun initialize(request: InitRequest): InitInfo {
        val ctx = context ?: throw Errors.of("internal", "Plugin is not attached to an engine")
        val manifestAppId = readManifestAppId(ctx)
        if (manifestAppId.isNullOrBlank()) {
            throw Errors.of(
                "invalidConfig",
                "Missing <meta-data android:name=\"$APP_ID_KEY\"> in AndroidManifest.xml " +
                    "(see doc/setup/admob.md)",
            )
        }
        // GMA Next-Gen takes the App ID in code; UMP still reads the manifest
        // entry, so both must name the same app.
        val configured = request.appId
        if (!configured.isNullOrBlank() && configured != manifestAppId) {
            Log.w(TAG, "NetworkConfig.appId differs from the manifest App ID; the manifest value is used.")
        }
        testDeviceIds = request.testDeviceIds
        val metaAdapter = MetaBidding.detect()
        if (initialized) {
            MobileAds.setRequestConfiguration(requestConfiguration())
            return InitInfo(metaAdapter)
        }

        // Next-Gen requires initialization on a worker thread. The request
        // configuration goes in with it, so ads preloaded during initialization
        // already carry the test-device and age settings.
        val config = InitializationConfig.Builder(manifestAppId)
            .setRequestConfiguration(requestConfiguration())
            .build()
        suspendCancellableCoroutine { cont ->
            Thread {
                MobileAds.initialize(ctx, config) {
                    mainHandler.post { if (cont.isActive) cont.resume(Unit) }
                }
            }.start()
        }
        initialized = true
        return InitInfo(metaAdapter)
    }

    override suspend fun load(format: AdFormatMessage, adUnitId: String): String {
        if (!initialized) throw Errors.of("notInitialized", "AdMob is not initialized")
        return fullScreen.load(format, buildRequest(adUnitId))
    }

    override suspend fun show(adId: String) = fullScreen.show(adId, activity)

    override fun destroy(adId: String) = fullScreen.destroy(adId)

    override fun applyConsent(consent: ConsentMessage) {
        coppa = consent.coppa
        if (initialized) MobileAds.setRequestConfiguration(requestConfiguration())
        // Opt-in Meta bidding: privacy reaches Audience Network before
        // MobileAds initializes the adapter (consent is applied before init).
        if (MetaBidding.detect() != null) MetaBidding.applyPrivacy(consent.ccpaOptOut, consent.coppa)
        val ctx = context ?: return
        // Restricted data processing (US state privacy laws), the documented
        // mechanism: `gad_rdp` in the default SharedPreferences.
        val prefs = Consent.defaultPreferences(ctx).edit()
        when (consent.ccpaOptOut) {
            true -> prefs.putInt("gad_rdp", 1)
            false -> prefs.remove("gad_rdp")
            null -> Unit
        }
        prefs.apply()
    }

    override fun dispose() = fullScreen.clear()

    override suspend fun gatherConsent(request: GatherRequest): ConsentInfo {
        val current = activity ?: throw Errors.of("noActivity", "No foreground Activity for the consent form")
        return Consent.gather(current, request)
    }

    override suspend fun showPrivacyOptions() {
        val current = activity ?: throw Errors.of("noActivity", "No foreground Activity for the privacy form")
        Consent.showPrivacyOptions(current)
    }

    override fun consentInfo(): ConsentInfo {
        val ctx = context ?: throw Errors.of("internal", "Plugin is not attached")
        return Consent.snapshot(ctx)
    }

    // endregion

    /** Rebuilt from our own state: Next-Gen has no public `toBuilder()`. */
    private fun requestConfiguration(): RequestConfiguration = RequestConfiguration.Builder()
        .setTestDeviceIds(testDeviceIds)
        .setAgeRestrictedTreatment(
            if (coppa) AgeRestrictedTreatment.CHILD else AgeRestrictedTreatment.UNSPECIFIED,
        )
        .build()

    private fun readManifestAppId(ctx: Context): String? = runCatching {
        val info = ctx.packageManager.getApplicationInfo(ctx.packageName, PackageManager.GET_META_DATA)
        info.metaData?.getString(APP_ID_KEY)
    }.getOrNull()
}
