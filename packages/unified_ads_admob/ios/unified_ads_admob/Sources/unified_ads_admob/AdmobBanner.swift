import Flutter
import GoogleMobileAds
import UIKit

let bannerViewType = "dev.arovyx.plugin.unifiedads/admob/banner"

/// Creates `AdmobBannerView`s for `UnifiedBannerWidget`.
final class AdmobBannerFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: UnifiedAdsAdmobPlugin?

  init(plugin: UnifiedAdsAdmobPlugin) {
    self.plugin = plugin
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    AdmobBannerView(frame: frame, params: args as? [String: Any] ?? [:], plugin: plugin)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A native AdMob `BannerView` hosted in a Flutter platform view.
final class AdmobBannerView: NSObject, FlutterPlatformView, BannerViewDelegate {
  private let container: UIView
  private let adId: String
  private var bannerView: BannerView?
  private weak var plugin: UnifiedAdsAdmobPlugin?

  init(frame: CGRect, params: [String: Any], plugin: UnifiedAdsAdmobPlugin?) {
    container = UIView(frame: frame)
    adId = params["adId"] as? String ?? ""
    self.plugin = plugin
    super.init()

    let banner = BannerView(adSize: Self.adSize(from: params["size"] as? [String: Any]))
    banner.adUnitID = params["adUnitId"] as? String ?? ""
    banner.rootViewController = UnifiedAdsAdmobPlugin.topViewController()
    banner.delegate = self
    banner.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(banner)
    NSLayoutConstraint.activate([
      banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      banner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    bannerView = banner
    banner.load(Request())
  }

  deinit {
    bannerView?.delegate = nil
    bannerView?.removeFromSuperview()
  }

  func view() -> UIView {
    container
  }

  // MARK: BannerViewDelegate

  func bannerViewDidReceiveAd(_ bannerView: BannerView) {
    let size = cgSize(for: bannerView.adSize)
    plugin?.emit(
      AdEventMessage(
        kind: .bannerSized, adId: adId, format: .banner, width: Double(size.width),
        height: Double(size.height)))
    plugin?.emit(AdEventMessage(kind: .loaded, adId: adId, format: .banner))
  }

  func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
    let ns = error as NSError
    plugin?.emit(
      AdEventMessage(
        kind: .failedToLoad, adId: adId, format: .banner, errorCode: Errors.loadCode(ns.code),
        errorMessage: ns.localizedDescription, nativeCode: String(ns.code)))
  }

  func bannerViewDidRecordImpression(_ bannerView: BannerView) {
    plugin?.emit(AdEventMessage(kind: .impression, adId: adId, format: .banner))
  }

  func bannerViewDidRecordClick(_ bannerView: BannerView) {
    plugin?.emit(AdEventMessage(kind: .clicked, adId: adId, format: .banner))
  }

  // MARK: Size mapping

  private static func adSize(from size: [String: Any]?) -> AdSize {
    let width = CGFloat((size?["width"] as? NSNumber)?.doubleValue ?? Double(UIScreen.main.bounds.width))
    switch size?["type"] as? String {
    case "largeBanner": return AdSizeLargeBanner
    case "mediumRectangle": return AdSizeMediumRectangle
    case "leaderboard": return AdSizeLeaderboard
    case "adaptiveAnchored": return largeAnchoredAdaptiveBanner(width: width)
    case "adaptiveInline":
      if let maxHeight = (size?["maxHeight"] as? NSNumber)?.doubleValue {
        return inlineAdaptiveBanner(width: width, maxHeight: CGFloat(maxHeight))
      }
      return currentOrientationInlineAdaptiveBanner(width: width)
    default: return AdSizeBanner
    }
  }
}
