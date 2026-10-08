import Flutter
import UIKit
import UnityAds

final class UnityBannerFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: UnifiedAdsUnityPlugin?

  init(plugin: UnifiedAdsUnityPlugin) { self.plugin = plugin }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    UnityBannerView(frame: frame, params: args as? [String: Any] ?? [:], plugin: plugin)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A Unity `UADSBannerAd` in a Flutter platform view. Adaptive sizes are not
/// documented for the 4.19+ API, so they fall back to 320×50.
final class UnityBannerView: NSObject, FlutterPlatformView, UADSBannerAdDelegate {
  private let container: UIView
  private let adId: String
  private var bannerAd: UADSBannerAd?
  private weak var plugin: UnifiedAdsUnityPlugin?

  init(frame: CGRect, params: [String: Any], plugin: UnifiedAdsUnityPlugin?) {
    container = UIView(frame: frame)
    adId = params["adId"] as? String ?? ""
    self.plugin = plugin
    super.init()

    let size: CGSize
    switch (params["size"] as? [String: Any])?["type"] as? String {
    case "mediumRectangle": size = CGSize(width: 300, height: 250)
    case "leaderboard": size = CGSize(width: 728, height: 90)
    default: size = CGSize(width: 320, height: 50)
    }
    let configuration = UADSBannerLoadConfigurationBuilder(
      placementId: params["adUnitId"] as? String ?? "", bannerSize: size, delegate: self
    ).build()
    UADSBannerAd.load(configuration) { [weak self] ad, error in
      guard let self else { return }
      guard let ad else {
        self.fail(code: error?.code ?? 52100, message: error?.message ?? "Unity banner failed")
        return
      }
      self.bannerAd = ad
      ad.view.translatesAutoresizingMaskIntoConstraints = false
      self.container.addSubview(ad.view)
      NSLayoutConstraint.activate([
        ad.view.centerXAnchor.constraint(equalTo: self.container.centerXAnchor),
        ad.view.centerYAnchor.constraint(equalTo: self.container.centerYAnchor),
      ])
      self.plugin?.emit(
        AdEventMessage(
          kind: .bannerSized, adId: self.adId, format: .banner, width: Double(size.width),
          height: Double(size.height)))
      self.plugin?.emit(AdEventMessage(kind: .loaded, adId: self.adId, format: .banner))
    }
  }

  deinit {
    bannerAd?.view.removeFromSuperview()
  }

  func view() -> UIView { container }

  private func fail(code: Int, message: String) {
    plugin?.emit(
      AdEventMessage(
        kind: .failedToLoad, adId: adId, format: .banner, errorCode: UnityErrors.loadCode(code),
        errorMessage: message, nativeCode: String(code)))
  }

  func bannerImpression(_ bannerAd: UADSBannerAd) {
    plugin?.emit(AdEventMessage(kind: .impression, adId: adId, format: .banner))
  }

  func bannerDidClick(_ bannerAd: UADSBannerAd) {
    plugin?.emit(AdEventMessage(kind: .clicked, adId: adId, format: .banner))
  }

  func bannerDidFailShow(_ bannerAd: UADSBannerAd, error: UnityAdsError) {
    fail(code: error.code, message: error.message)
  }
}
