package dev.arovyx.plugin.unifiedads.admob

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.google.android.libraries.ads.mobile.sdk.appopen.AppOpenAd
import com.google.android.libraries.ads.mobile.sdk.appopen.AppOpenAdEventCallback
import com.google.android.libraries.ads.mobile.sdk.common.Ad
import com.google.android.libraries.ads.mobile.sdk.common.AdEventCallback
import com.google.android.libraries.ads.mobile.sdk.common.AdLoadCallback
import com.google.android.libraries.ads.mobile.sdk.common.AdRequest
import com.google.android.libraries.ads.mobile.sdk.common.FullScreenContentError
import com.google.android.libraries.ads.mobile.sdk.common.LoadAdError
import com.google.android.libraries.ads.mobile.sdk.interstitial.InterstitialAd
import com.google.android.libraries.ads.mobile.sdk.interstitial.InterstitialAdEventCallback
import com.google.android.libraries.ads.mobile.sdk.rewarded.OnUserEarnedRewardListener
import com.google.android.libraries.ads.mobile.sdk.rewarded.RewardedAd
import com.google.android.libraries.ads.mobile.sdk.rewarded.RewardedAdEventCallback
import com.google.android.libraries.ads.mobile.sdk.rewardedinterstitial.RewardedInterstitialAd
import com.google.android.libraries.ads.mobile.sdk.rewardedinterstitial.RewardedInterstitialAdEventCallback
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Loaded full-screen ads (interstitial, rewarded, rewarded interstitial, app
 * open), keyed by the id returned to Dart.
 *
 * GMA Next-Gen calls load and event callbacks on background threads, so every
 * callback hops to the main thread first; [ads] is only touched there.
 */
internal class FullScreenAds(private val emitter: AdEventEmitter) {
    private class Holder(val id: String, val format: AdFormatMessage, val ad: Ad) {
        var showContinuation: CancellableContinuation<Unit>? = null

        fun clear() {
            when (ad) {
                is InterstitialAd -> ad.adEventCallback = null
                is RewardedAd -> ad.adEventCallback = null
                is RewardedInterstitialAd -> ad.adEventCallback = null
                is AppOpenAd -> ad.adEventCallback = null
            }
            ad.destroy()
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private val ads = mutableMapOf<String, Holder>()
    private var counter = 0

    private fun onMain(block: () -> Unit) {
        main.post(block)
    }

    suspend fun load(format: AdFormatMessage, request: AdRequest): String =
        suspendCancellableCoroutine { cont ->
            fun <T : Ad> loaded(attach: (T, Holder) -> Unit) = object : AdLoadCallback<T> {
                override fun onAdLoaded(ad: T) = onMain {
                    val holder = register(format, ad)
                    attach(ad, holder)
                    onLoaded(holder, cont)
                }

                override fun onAdFailedToLoad(adError: LoadAdError) = onMain {
                    if (cont.isActive) cont.resumeWithException(Errors.load(adError))
                }
            }

            when (format) {
                AdFormatMessage.INTERSTITIAL -> InterstitialAd.load(
                    request,
                    loaded<InterstitialAd> { ad, holder ->
                        ad.adEventCallback =
                            object : InterstitialAdEventCallback, AdEventCallback by events(holder) {}
                    },
                )

                AdFormatMessage.REWARDED -> RewardedAd.load(
                    request,
                    loaded<RewardedAd> { ad, holder ->
                        ad.adEventCallback =
                            object : RewardedAdEventCallback, AdEventCallback by events(holder) {}
                    },
                )

                AdFormatMessage.REWARDED_INTERSTITIAL -> RewardedInterstitialAd.load(
                    request,
                    loaded<RewardedInterstitialAd> { ad, holder ->
                        ad.adEventCallback =
                            object : RewardedInterstitialAdEventCallback, AdEventCallback by events(holder) {}
                    },
                )

                AdFormatMessage.APP_OPEN -> AppOpenAd.load(
                    request,
                    loaded<AppOpenAd> { ad, holder ->
                        ad.adEventCallback =
                            object : AppOpenAdEventCallback, AdEventCallback by events(holder) {}
                    },
                )

                AdFormatMessage.BANNER -> cont.resumeWithException(
                    Errors.of("unsupportedFormat", "Banners are loaded through the platform view"),
                )
            }
        }

    private fun register(format: AdFormatMessage, ad: Ad): Holder {
        val holder = Holder("admob-${++counter}", format, ad)
        ads[holder.id] = holder
        return holder
    }

    private fun onLoaded(holder: Holder, cont: CancellableContinuation<String>) {
        if (!cont.isActive) {
            // Dart gave up (e.g. engine detached); release the ad.
            ads.remove(holder.id)?.clear()
            return
        }
        emitter.emit(AdEventMessage(AdEventKind.LOADED, holder.id, holder.format))
        cont.resume(holder.id)
    }

    /** Must be called on the main thread (the Pigeon host API runs there). */
    suspend fun show(adId: String, activity: Activity?) {
        val holder = ads[adId] ?: throw Errors.of("notReady", "No loaded AdMob ad with id $adId")
        if (activity == null) throw Errors.of("noActivity", "No foreground Activity to show the ad")
        suspendCancellableCoroutine { cont ->
            holder.showContinuation = cont
            val onReward = OnUserEarnedRewardListener { reward ->
                emitter.emit(
                    AdEventMessage(
                        kind = AdEventKind.EARNED_REWARD,
                        adId = holder.id,
                        format = holder.format,
                        rewardAmount = reward.amount.toDouble(),
                        rewardType = reward.type,
                    ),
                )
            }
            when (val ad = holder.ad) {
                is InterstitialAd -> ad.show(activity)
                is RewardedAd -> ad.show(activity, onReward)
                is RewardedInterstitialAd -> ad.show(activity, onReward)
                is AppOpenAd -> ad.show(activity)
            }
        }
    }

    /** Shared full-screen event handling; every callback is posted to the main thread. */
    private fun events(holder: Holder) = object : AdEventCallback {
        override fun onAdShowedFullScreenContent() = onMain {
            emitter.emit(AdEventMessage(AdEventKind.SHOWN, holder.id, holder.format))
            holder.showContinuation?.takeIf { it.isActive }?.resume(Unit)
            holder.showContinuation = null
        }

        override fun onAdFailedToShowFullScreenContent(fullScreenContentError: FullScreenContentError) = onMain {
            ads.remove(holder.id)
            val failure = Errors.show(fullScreenContentError)
            emitter.emit(
                AdEventMessage(
                    kind = AdEventKind.FAILED_TO_SHOW,
                    adId = holder.id,
                    format = holder.format,
                    errorCode = failure.code,
                    errorMessage = failure.message,
                    nativeCode = fullScreenContentError.code.name,
                ),
            )
            holder.showContinuation?.takeIf { it.isActive }?.resumeWithException(failure)
            holder.showContinuation = null
            holder.clear()
        }

        override fun onAdImpression() = onMain {
            emitter.emit(AdEventMessage(AdEventKind.IMPRESSION, holder.id, holder.format))
        }

        override fun onAdClicked() = onMain {
            emitter.emit(AdEventMessage(AdEventKind.CLICKED, holder.id, holder.format))
        }

        override fun onAdDismissedFullScreenContent() = onMain {
            ads.remove(holder.id)
            emitter.emit(AdEventMessage(AdEventKind.CLOSED, holder.id, holder.format))
            holder.clear()
        }
    }

    fun destroy(adId: String) {
        ads.remove(adId)?.clear()
    }

    fun clear() {
        ads.values.forEach { it.clear() }
        ads.clear()
    }
}
