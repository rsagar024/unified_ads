package dev.arovyx.plugin.unifiedads.ironsource

import android.content.Context
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.unity3d.mediation.LevelPlayAdError
import com.unity3d.mediation.LevelPlayAdInfo
import com.unity3d.mediation.LevelPlayAdSize
import com.unity3d.mediation.banner.LevelPlayBannerAdView
import com.unity3d.mediation.banner.LevelPlayBannerAdViewListener
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class IronsourceBannerFactory(private val plugin: UnifiedAdsIronsourcePlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        IronsourceBannerView(plugin.activity ?: context, args as? Map<*, *> ?: emptyMap<String, Any?>(), plugin)
}

/** A `LevelPlayBannerAdView` hosted in a Flutter platform view. */
internal class IronsourceBannerView(
    context: Context,
    params: Map<*, *>,
    private val plugin: UnifiedAdsIronsourcePlugin,
) : PlatformView, LevelPlayBannerAdViewListener {
    private val adId = params["adId"] as? String ?: ""
    private val container = FrameLayout(context)
    private var banner: LevelPlayBannerAdView? = null

    init {
        val size = params["size"] as? Map<*, *>
        val width = (size?.get("width") as? Number)?.toInt()
        val adSize = when (size?.get("type") as? String) {
            "largeBanner" -> LevelPlayAdSize.LARGE
            "mediumRectangle" -> LevelPlayAdSize.MEDIUM_RECTANGLE
            "leaderboard" -> LevelPlayAdSize.LEADERBOARD
            "adaptiveAnchored", "adaptiveInline" ->
                LevelPlayAdSize.createAdaptiveAdSize(context, width) ?: LevelPlayAdSize.BANNER
            else -> LevelPlayAdSize.BANNER
        }
        val config = LevelPlayBannerAdView.Config.Builder().setAdSize(adSize).build()
        val view = LevelPlayBannerAdView(context, params["adUnitId"] as? String ?: "", config)
        view.setBannerListener(this)
        container.addView(
            view,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )
        banner = view
        view.loadAd()
    }

    override fun getView(): View = container

    override fun dispose() {
        banner?.let {
            container.removeView(it)
            it.destroy()
        }
        banner = null
    }

    private fun send(kind: AdEventKind) =
        plugin.emit(AdEventMessage(kind, adId, AdFormatMessage.BANNER))

    override fun onAdLoaded(adInfo: LevelPlayAdInfo) {
        val size = adInfo.adSize ?: banner?.adSize
        if (size != null) {
            plugin.emit(
                AdEventMessage(
                    kind = AdEventKind.BANNER_SIZED,
                    adId = adId,
                    format = AdFormatMessage.BANNER,
                    width = size.width.toDouble(),
                    height = size.height.toDouble(),
                ),
            )
        }
        send(AdEventKind.LOADED)
    }

    override fun onAdLoadFailed(error: LevelPlayAdError) {
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

    override fun onAdDisplayed(adInfo: LevelPlayAdInfo) = send(AdEventKind.IMPRESSION)

    override fun onAdClicked(adInfo: LevelPlayAdInfo) = send(AdEventKind.CLICKED)
}
