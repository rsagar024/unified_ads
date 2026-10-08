import GoogleMobileAds
import UIKit

/// A loaded full-screen ad (interstitial, rewarded, rewarded interstitial or
/// app open) and its delegate.
final class FullScreenAdHolder: NSObject, FullScreenContentDelegate {
  let id: String
  let format: AdFormatMessage
  var interstitial: InterstitialAd?
  var rewarded: RewardedAd?
  var rewardedInterstitial: RewardedInterstitialAd?
  var appOpen: AppOpenAd?
  var showContinuation: CheckedContinuation<Void, Error>?
  private weak var plugin: UnifiedAdsAdmobPlugin?

  init(id: String, format: AdFormatMessage, plugin: UnifiedAdsAdmobPlugin) {
    self.id = id
    self.format = format
    self.plugin = plugin
  }

  func clear() {
    interstitial?.fullScreenContentDelegate = nil
    rewarded?.fullScreenContentDelegate = nil
    rewardedInterstitial?.fullScreenContentDelegate = nil
    appOpen?.fullScreenContentDelegate = nil
    interstitial = nil
    rewarded = nil
    rewardedInterstitial = nil
    appOpen = nil
  }

  private func emit(_ kind: AdEventKind) {
    plugin?.emit(AdEventMessage(kind: kind, adId: id, format: format))
  }

  // MARK: FullScreenContentDelegate

  func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
    emit(.shown)
    showContinuation?.resume()
    showContinuation = nil
  }

  func ad(
    _ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error
  ) {
    let failure = Errors.show(error)
    plugin?.emit(
      AdEventMessage(
        kind: .failedToShow, adId: id, format: format, errorCode: failure.code,
        errorMessage: failure.message, nativeCode: String((error as NSError).code)))
    showContinuation?.resume(throwing: failure)
    showContinuation = nil
    plugin?.removeAd(id)
  }

  func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
    emit(.impression)
  }

  func adDidRecordClick(_ ad: FullScreenPresentingAd) {
    emit(.clicked)
  }

  func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
    emit(.closed)
    plugin?.removeAd(id)
  }
}
