package dev.arovyx.plugin.unifiedads.admob

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.google.android.libraries.ads.mobile.sdk.banner.AdSize
import com.google.android.libraries.ads.mobile.sdk.banner.AdView
import com.google.android.libraries.ads.mobile.sdk.banner.BannerAd
import com.google.android.libraries.ads.mobile.sdk.banner.BannerAdEventCallback
import com.google.android.libraries.ads.mobile.sdk.banner.BannerAdRequest
import com.google.android.libraries.ads.mobile.sdk.common.AdLoadCallback
import com.google.android.libraries.ads.mobile.sdk.common.LoadAdError
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal const val BANNER_VIEW_TYPE = "dev.arovyx.plugin.unifiedads/admob/banner"

/** Creates [AdmobBannerView]s for `UnifiedBannerWidget`. */
internal class AdmobBannerFactory(private val plugin: UnifiedAdsAdmobPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any?>()
        // An Activity context lets click-throughs open correctly.
        return AdmobBannerView(plugin.activity ?: context, params, plugin)
    }
}

/** A native AdMob [AdView] hosted in a Flutter platform view. */
internal class AdmobBannerView(
    context: Context,
    params: Map<*, *>,
    private val plugin: UnifiedAdsAdmobPlugin,
) : PlatformView {
    private val adId = params["adId"] as? String ?: ""
    private val main = Handler(Looper.getMainLooper())
    private val container = FrameLayout(context)
    private var adView: AdView? = AdView(context)

    init {
        val view = adView!!
        container.addView(
            view,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )
        val request = BannerAdRequest.Builder(
            params["adUnitId"] as? String ?: "",
            sizeFrom(context, params["size"] as? Map<*, *>),
        ).build()
        // Next-Gen delivers these callbacks on a background thread; everything
        // below runs on the main thread, and nothing runs after dispose().
        view.loadAd(
            request,
            object : AdLoadCallback<BannerAd> {
                override fun onAdLoaded(ad: BannerAd) {
                    main.post { if (adView == null) ad.destroy() else onLoaded(ad) }
                }

                override fun onAdFailedToLoad(adError: LoadAdError) {
                    main.post {
                        if (adView == null) return@post
                        plugin.emit(
                            AdEventMessage(
                                kind = AdEventKind.FAILED_TO_LOAD,
                                adId = adId,
                                format = AdFormatMessage.BANNER,
                                errorCode = Errors.loadCode(adError.code),
                                errorMessage = adError.message,
                                nativeCode = adError.code.name,
                            ),
                        )
                    }
                }
            },
        )
    }

    private fun onLoaded(ad: BannerAd) {
        ad.adEventCallback = object : BannerAdEventCallback {
            override fun onAdImpression() {
                main.post { plugin.emit(AdEventMessage(AdEventKind.IMPRESSION, adId, AdFormatMessage.BANNER)) }
            }

            override fun onAdClicked() {
                main.post { plugin.emit(AdEventMessage(AdEventKind.CLICKED, adId, AdFormatMessage.BANNER)) }
            }
        }
        val size = ad.getAdSize()
        plugin.emit(
            AdEventMessage(
                kind = AdEventKind.BANNER_SIZED,
                adId = adId,
                format = AdFormatMessage.BANNER,
                width = size.width.toDouble(),
                height = size.height.toDouble(),
            ),
        )
        plugin.emit(AdEventMessage(AdEventKind.LOADED, adId, AdFormatMessage.BANNER))
    }

    override fun getView(): View = container

    override fun dispose() {
        adView?.let {
            it.getBannerAd()?.adEventCallback = null
            container.removeView(it)
            it.destroy()
        }
        adView = null
    }

    private companion object {
        fun sizeFrom(context: Context, size: Map<*, *>?): AdSize {
            val metrics = context.resources.displayMetrics
            val screenWidthDp = (metrics.widthPixels / metrics.density).toInt()
            val width = (size?.get("width") as? Number)?.toInt() ?: screenWidthDp
            return when (size?.get("type") as? String) {
                "largeBanner" -> AdSize.LARGE_BANNER
                "mediumRectangle" -> AdSize.MEDIUM_RECTANGLE
                "leaderboard" -> AdSize.LEADERBOARD
                "adaptiveAnchored" -> AdSize.getLargeAnchoredAdaptiveBannerAdSize(context, width)
                "adaptiveInline" -> {
                    val maxHeight = (size["maxHeight"] as? Number)?.toInt()
                    if (maxHeight != null) {
                        AdSize.getInlineAdaptiveBannerAdSize(width, maxHeight)
                    } else {
                        AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(context, width)
                    }
                }
                else -> AdSize.BANNER
            }
        }
    }
}
