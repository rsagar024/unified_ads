package dev.arovyx.plugin.unifiedads.startapp

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.startapp.sdk.ads.banner.Banner
import com.startapp.sdk.ads.banner.BannerListener
import com.startapp.sdk.ads.banner.Mrec
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class StartappBannerFactory(private val plugin: UnifiedAdsStartappPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        StartappBannerView(plugin.activity ?: context, args as? Map<*, *> ?: emptyMap<String, Any?>(), plugin)
}

/**
 * A Start.io `Banner` (320×50) or `Mrec` (300×250) in a Flutter platform view.
 * Start.io has no adaptive banner; other sizes fall back to 320×50.
 */
internal class StartappBannerView(
    context: Context,
    params: Map<*, *>,
    private val plugin: UnifiedAdsStartappPlugin,
) : PlatformView, BannerListener {
    private val adId = params["adId"] as? String ?: ""
    private val container = FrameLayout(context)
    private val type = (params["size"] as? Map<*, *>)?.get("type") as? String
    private val size = Errors.bannerSize(type)

    init {
        val preferences = plugin.preferences(params["adUnitId"] as? String)
        val banner = if (type == "mediumRectangle") {
            Mrec(context, preferences, this)
        } else {
            Banner(context, preferences, this)
        }
        container.addView(
            banner,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        banner.loadAd(size.first, size.second)
    }

    override fun getView(): View = container

    // No destroy() exists on Start.io banners: detach the view.
    override fun dispose() = container.removeAllViews()

    private fun send(kind: AdEventKind) =
        plugin.emit(AdEventMessage(kind, adId, AdFormatMessage.BANNER))

    override fun onReceiveAd(view: View) {
        plugin.emit(
            AdEventMessage(
                kind = AdEventKind.BANNER_SIZED,
                adId = adId,
                format = AdFormatMessage.BANNER,
                width = size.first.toDouble(),
                height = size.second.toDouble(),
            ),
        )
        send(AdEventKind.LOADED)
    }

    override fun onFailedToReceiveAd(view: View?) {
        plugin.emit(
            AdEventMessage(
                kind = AdEventKind.FAILED_TO_LOAD,
                adId = adId,
                format = AdFormatMessage.BANNER,
                errorCode = "noFill",
                errorMessage = "Start.io returned no banner",
            ),
        )
    }

    override fun onImpression(view: View) = send(AdEventKind.IMPRESSION)

    override fun onClick(view: View) = send(AdEventKind.CLICKED)
}
