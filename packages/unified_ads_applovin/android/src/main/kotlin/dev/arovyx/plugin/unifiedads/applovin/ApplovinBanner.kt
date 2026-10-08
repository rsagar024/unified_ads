package dev.arovyx.plugin.unifiedads.applovin

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdFormat
import com.applovin.mediation.MaxAdRevenueListener
import com.applovin.mediation.MaxAdViewAdListener
import com.applovin.mediation.MaxError
import com.applovin.mediation.ads.MaxAdView
import com.applovin.mediation.MaxAdViewConfiguration
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class ApplovinBannerFactory(private val plugin: UnifiedAdsApplovinPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        ApplovinBannerView(context, args as? Map<*, *> ?: emptyMap<String, Any?>(), plugin)
}

/** A MAX banner / MREC (`MaxAdView`) hosted in a Flutter platform view. */
internal class ApplovinBannerView(
    context: Context,
    params: Map<*, *>,
    private val plugin: UnifiedAdsApplovinPlugin,
) : PlatformView, MaxAdViewAdListener, MaxAdRevenueListener {
    private val adId = params["adId"] as? String ?: ""
    private val container = FrameLayout(context)
    private var adView: MaxAdView? = null

    init {
        val size = params["size"] as? Map<*, *>
        val unit = params["adUnitId"] as? String ?: ""
        val metrics = context.resources.displayMetrics
        val width = (size?.get("width") as? Number)?.toInt()
            ?: (metrics.widthPixels / metrics.density).toInt()
        val view = when (size?.get("type") as? String) {
            "mediumRectangle" -> MaxAdView(unit, MaxAdFormat.MREC)
            "leaderboard" -> MaxAdView(unit, MaxAdFormat.LEADER)
            "adaptiveAnchored" -> MaxAdView(
                unit,
                MaxAdViewConfiguration.builder()
                    .setAdaptiveType(MaxAdViewConfiguration.AdaptiveType.ANCHORED)
                    .setAdaptiveWidth(width)
                    .build(),
            )
            "adaptiveInline" -> MaxAdView(
                unit,
                MaxAdViewConfiguration.builder()
                    .setAdaptiveType(MaxAdViewConfiguration.AdaptiveType.INLINE)
                    .setAdaptiveWidth(width)
                    .apply {
                        (size["maxHeight"] as? Number)?.let { setInlineMaximumHeight(it.toInt()) }
                    }
                    .build(),
            )
            else -> MaxAdView(
                unit,
                MaxAdViewConfiguration.builder()
                    .setAdaptiveType(MaxAdViewConfiguration.AdaptiveType.NONE)
                    .build(),
            )
        }
        view.setListener(this)
        view.setRevenueListener(this)
        container.addView(
            view,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        adView = view
        view.loadAd()
    }

    override fun getView(): View = container

    override fun dispose() {
        adView?.let {
            it.setListener(null)
            it.setRevenueListener(null)
            container.removeView(it)
            it.destroy()
        }
        adView = null
    }

    private fun send(kind: AdEventKind) =
        plugin.emit(AdEventMessage(kind, adId, AdFormatMessage.BANNER))

    override fun onAdLoaded(ad: MaxAd) {
        plugin.emit(
            AdEventMessage(
                kind = AdEventKind.BANNER_SIZED,
                adId = adId,
                format = AdFormatMessage.BANNER,
                width = ad.size.width.toDouble(),
                height = ad.size.height.toDouble(),
            ),
        )
        send(AdEventKind.LOADED)
    }

    override fun onAdLoadFailed(adUnitId: String, error: MaxError) {
        plugin.emit(
            AdEventMessage(
                kind = AdEventKind.FAILED_TO_LOAD,
                adId = adId,
                format = AdFormatMessage.BANNER,
                errorCode = Errors.loadCode(error.code),
                errorMessage = error.message,
                nativeCode = error.code.toString(),
            ),
        )
    }

    override fun onAdClicked(ad: MaxAd) = send(AdEventKind.CLICKED)

    override fun onAdRevenuePaid(ad: MaxAd) = send(AdEventKind.IMPRESSION)

    override fun onAdDisplayed(ad: MaxAd) = Unit

    override fun onAdHidden(ad: MaxAd) = Unit

    override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) = Unit

    override fun onAdExpanded(ad: MaxAd) = Unit

    override fun onAdCollapsed(ad: MaxAd) = Unit
}
