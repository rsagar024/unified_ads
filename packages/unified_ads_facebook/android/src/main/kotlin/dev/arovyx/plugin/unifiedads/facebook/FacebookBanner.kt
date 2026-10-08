package dev.arovyx.plugin.unifiedads.facebook

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.facebook.ads.Ad
import com.facebook.ads.AdError
import com.facebook.ads.AdListener
import com.facebook.ads.AdSize
import com.facebook.ads.AdView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class FacebookBannerFactory(private val plugin: UnifiedAdsFacebookPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        FacebookBannerView(plugin.activity ?: context, args as? Map<*, *> ?: emptyMap<String, Any?>(), plugin)
}

/**
 * An Audience Network `AdView` in a Flutter platform view. Audience Network
 * banners are full-width with a fixed height: 50 (standard / adaptive), 90
 * (large banner, leaderboard) or 250 (medium rectangle).
 */
internal class FacebookBannerView(
    context: Context,
    params: Map<*, *>,
    private val plugin: UnifiedAdsFacebookPlugin,
) : PlatformView, AdListener {
    private val adId = params["adId"] as? String ?: ""
    private val container = FrameLayout(context)
    private val size: AdSize
    private var adView: AdView? = null

    init {
        val sizeMap = params["size"] as? Map<*, *>
        size = when (sizeMap?.get("type") as? String) {
            "mediumRectangle" -> AdSize.RECTANGLE_HEIGHT_250
            "largeBanner", "leaderboard" -> AdSize.BANNER_HEIGHT_90
            else -> AdSize.BANNER_HEIGHT_50
        }
        val view = AdView(context, params["adUnitId"] as? String ?: "", size)
        container.addView(
            view,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        adView = view
        view.loadAd(view.buildLoadAdConfig().withAdListener(this).build())
    }

    override fun getView(): View = container

    override fun dispose() {
        // Unlike some older plugins, always destroy the AdView (avoids leaks).
        adView?.let {
            container.removeView(it)
            it.destroy()
        }
        adView = null
    }

    private fun send(kind: AdEventKind) =
        plugin.emit(AdEventMessage(kind, adId, AdFormatMessage.BANNER))

    override fun onAdLoaded(ad: Ad) {
        val metrics = container.resources.displayMetrics
        // Width -1 means "match parent": report the screen width in dp.
        val width = if (size.width > 0) size.width else (metrics.widthPixels / metrics.density).toInt()
        plugin.emit(
            AdEventMessage(
                kind = AdEventKind.BANNER_SIZED,
                adId = adId,
                format = AdFormatMessage.BANNER,
                width = width.toDouble(),
                height = size.height.toDouble(),
            ),
        )
        send(AdEventKind.LOADED)
    }

    override fun onError(ad: Ad, error: AdError) {
        plugin.emit(
            AdEventMessage(
                kind = AdEventKind.FAILED_TO_LOAD,
                adId = adId,
                format = AdFormatMessage.BANNER,
                errorCode = Errors.loadCode(error.errorCode),
                errorMessage = error.errorMessage,
                nativeCode = error.errorCode.toString(),
            ),
        )
    }

    override fun onAdClicked(ad: Ad) = send(AdEventKind.CLICKED)

    override fun onLoggingImpression(ad: Ad) = send(AdEventKind.IMPRESSION)
}
