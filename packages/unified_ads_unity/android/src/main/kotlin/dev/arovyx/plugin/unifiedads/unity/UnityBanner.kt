package dev.arovyx.plugin.unifiedads.unity

import android.content.Context
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.unity3d.ads.BannerAd
import com.unity3d.ads.BannerConfiguration
import com.unity3d.ads.BannerShowListener
import com.unity3d.ads.BannerSize
import com.unity3d.ads.LoadListener
import com.unity3d.ads.UnityAdsError
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class UnityBannerFactory(private val plugin: UnifiedAdsUnityPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        UnityBannerView(plugin.activity ?: context, args as? Map<*, *> ?: emptyMap<String, Any?>(), plugin)
}

/**
 * A Unity `BannerAd` in a Flutter platform view. Adaptive sizes are not
 * documented for the 4.19+ API, so they fall back to 320×50.
 */
internal class UnityBannerView(
    context: Context,
    params: Map<*, *>,
    private val plugin: UnifiedAdsUnityPlugin,
) : PlatformView {
    private val adId = params["adId"] as? String ?: ""
    private val container = FrameLayout(context)
    private var bannerAd: BannerAd? = null
    private var disposed = false

    init {
        val (width, height) = when ((params["size"] as? Map<*, *>)?.get("type") as? String) {
            "mediumRectangle" -> 300 to 250
            "leaderboard" -> 728 to 90
            else -> 320 to 50
        }
        val showListener = object : BannerShowListener {
            override fun onImpression(ad: BannerAd) = send(AdEventKind.IMPRESSION)

            override fun onClicked(ad: BannerAd) = send(AdEventKind.CLICKED)

            override fun onFailedToShow(ad: BannerAd, error: UnityAdsError) = fail(error)
        }
        val configuration = BannerConfiguration.Builder(
            params["adUnitId"] as? String ?: "",
            BannerSize(width, height),
            showListener,
        ).build()
        BannerAd.load(
            configuration,
            object : LoadListener<BannerAd> {
                override fun onAdLoaded(ad: BannerAd?, error: UnityAdsError?) {
                    if (disposed) return
                    if (ad == null) {
                        if (error != null) fail(error) else send(AdEventKind.FAILED_TO_LOAD)
                        return
                    }
                    bannerAd = ad
                    container.addView(
                        ad.view,
                        FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            Gravity.CENTER,
                        ),
                    )
                    plugin.emit(
                        AdEventMessage(
                            kind = AdEventKind.BANNER_SIZED,
                            adId = adId,
                            format = AdFormatMessage.BANNER,
                            width = width.toDouble(),
                            height = height.toDouble(),
                        ),
                    )
                    send(AdEventKind.LOADED)
                }
            },
        )
    }

    private fun send(kind: AdEventKind) =
        plugin.emit(AdEventMessage(kind, adId, AdFormatMessage.BANNER))

    private fun fail(error: UnityAdsError) {
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

    override fun getView(): View = container

    override fun dispose() {
        // No destroy() is documented for the 4.19+ BannerAd: detach and drop it.
        disposed = true
        container.removeAllViews()
        bannerAd = null
    }
}
