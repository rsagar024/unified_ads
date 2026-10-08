package dev.arovyx.plugin.unifiedads.inmobi

import android.content.Context
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import com.inmobi.ads.AdMetaInfo
import com.inmobi.ads.InMobiAdRequestStatus
import com.inmobi.ads.InMobiBanner
import com.inmobi.ads.listeners.BannerAdEventListener
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class InmobiBannerFactory(private val plugin: UnifiedAdsInmobiPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        InmobiBannerView(plugin.activity ?: context, args as? Map<*, *> ?: emptyMap<String, Any?>(), plugin)
}

/**
 * An `InMobiBanner` in a Flutter platform view. InMobi has no adaptive size:
 * MREC is 300×250, leaderboard 728×90 and everything else 320×50.
 */
internal class InmobiBannerView(
    context: Context,
    params: Map<*, *>,
    private val plugin: UnifiedAdsInmobiPlugin,
) : PlatformView {
    private val adId = params["adId"] as? String ?: ""
    private val container = FrameLayout(context)
    private var banner: InMobiBanner? = null

    init {
        val type = (params["size"] as? Map<*, *>)?.get("type") as? String
        val (width, height) = when (type) {
            "mediumRectangle" -> 300 to 250
            "leaderboard" -> 728 to 90
            else -> 320 to 50
        }
        val placementId = (params["adUnitId"] as? String)?.toLongOrNull()
        if (placementId == null) {
            fail("invalidConfig", "InMobi placement IDs are numeric", null)
        } else {
            val density = context.resources.displayMetrics.density
            val view = InMobiBanner(context, placementId)
            // The size must be set through layout params before load().
            view.layoutParams = FrameLayout.LayoutParams(
                (width * density).toInt(),
                (height * density).toInt(),
                Gravity.CENTER,
            )
            view.setListener(
                object : BannerAdEventListener() {
                    override fun onAdLoadSucceeded(ad: InMobiBanner, info: AdMetaInfo) {
                        plugin.emit(
                            AdEventMessage(
                                kind = AdEventKind.BANNER_SIZED,
                                adId = adId,
                                format = AdFormatMessage.BANNER,
                                width = width.toDouble(),
                                height = height.toDouble(),
                            ),
                        )
                        plugin.emit(AdEventMessage(AdEventKind.LOADED, adId, AdFormatMessage.BANNER))
                    }

                    override fun onAdLoadFailed(ad: InMobiBanner, status: InMobiAdRequestStatus) {
                        val error = Errors.status(status)
                        fail(error.code, error.message ?: "InMobi banner failed", error.details?.toString())
                    }

                    override fun onAdClicked(ad: InMobiBanner, params: Map<Any, Any>) {
                        plugin.emit(AdEventMessage(AdEventKind.CLICKED, adId, AdFormatMessage.BANNER))
                    }

                    override fun onAdImpression(ad: InMobiBanner) {
                        plugin.emit(AdEventMessage(AdEventKind.IMPRESSION, adId, AdFormatMessage.BANNER))
                    }
                },
            )
            container.addView(view)
            banner = view
            view.load()
        }
    }

    private fun fail(code: String, message: String, nativeCode: String?) {
        plugin.emit(
            AdEventMessage(
                kind = AdEventKind.FAILED_TO_LOAD,
                adId = adId,
                format = AdFormatMessage.BANNER,
                errorCode = code,
                errorMessage = message,
                nativeCode = nativeCode,
            ),
        )
    }

    override fun getView(): View = container

    override fun dispose() {
        banner?.let {
            container.removeView(it)
            it.destroy()
        }
        banner = null
    }
}
