import Flutter
import StartApp
import UIKit

final class StartappBannerFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: UnifiedAdsStartappPlugin?

  init(plugin: UnifiedAdsStartappPlugin) { self.plugin = plugin }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    StartappBannerView(frame: frame, params: args as? [String: Any] ?? [:], plugin: plugin)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A Start.io `STABannerView` (320×50 or MREC 300×250) in a platform view.
final class StartappBannerView: NSObject, FlutterPlatformView, STABannerDelegateProtocol {
  private let container: UIView
  private let adId: String
  private let size: CGSize
  private var banner: STABannerView?
  private weak var plugin: UnifiedAdsStartappPlugin?

  init(frame: CGRect, params: [String: Any], plugin: UnifiedAdsStartappPlugin?) {
    container = UIView(frame: frame)
    adId = params["adId"] as? String ?? ""
    self.plugin = plugin
    let isMrec = (params["size"] as? [String: Any])?["type"] as? String == "mediumRectangle"
    size = isMrec ? CGSize(width: 300, height: 250) : CGSize(width: 320, height: 50)
    super.init()

    let staSize = isMrec ? STA_MRecAdSize_300x250 : STA_PortraitAdSize_320x50
    guard let view = STABannerView(size: staSize, autoOrigin: STAAdOrigin_Top, withDelegate: self) else {
      return
    }
    container.addSubview(view)
    banner = view
    view.loadAd()
  }

  deinit {
    banner?.removeFromSuperview()
  }

  func view() -> UIView { container }

  @objc(bannerAdIsReadyToDisplay:)
  func bannerAdIsReadyToDisplay(_ banner: STABannerView) {
    plugin?.emit(
      AdEventMessage(
        kind: .bannerSized, adId: adId, format: .banner, width: Double(size.width),
        height: Double(size.height)))
    plugin?.emit(AdEventMessage(kind: .loaded, adId: adId, format: .banner))
  }

  @objc(failedLoadBannerAd:withError:)
  func failedLoadBannerAd(_ banner: STABannerView, withError error: Error) {
    plugin?.emit(
      AdEventMessage(
        kind: .failedToLoad, adId: adId, format: .banner, errorCode: "noFill",
        errorMessage: error.localizedDescription, nativeCode: String((error as NSError).code)))
  }

  @objc(didSendImpressionForBannerAd:)
  func didSendImpressionForBannerAd(_ banner: STABannerView) {
    plugin?.emit(AdEventMessage(kind: .impression, adId: adId, format: .banner))
  }

  @objc(didClickBannerAd:)
  func didClickBannerAd(_ banner: STABannerView) {
    plugin?.emit(AdEventMessage(kind: .clicked, adId: adId, format: .banner))
  }
}
