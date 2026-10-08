import Flutter
import InMobiSDK
import UIKit

final class InmobiBannerFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: UnifiedAdsInmobiPlugin?

  init(plugin: UnifiedAdsInmobiPlugin) { self.plugin = plugin }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    InmobiBannerView(frame: frame, params: args as? [String: Any] ?? [:], plugin: plugin)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// An `IMBanner` in a Flutter platform view (MREC 300×250, leaderboard
/// 728×90, everything else 320×50; InMobi has no adaptive size).
final class InmobiBannerView: NSObject, FlutterPlatformView, IMBannerDelegate {
  private let container: UIView
  private let adId: String
  private var banner: IMBanner?
  private let size: CGSize
  private weak var plugin: UnifiedAdsInmobiPlugin?

  init(frame: CGRect, params: [String: Any], plugin: UnifiedAdsInmobiPlugin?) {
    container = UIView(frame: frame)
    adId = params["adId"] as? String ?? ""
    self.plugin = plugin
    switch (params["size"] as? [String: Any])?["type"] as? String {
    case "mediumRectangle": size = CGSize(width: 300, height: 250)
    case "leaderboard": size = CGSize(width: 728, height: 90)
    default: size = CGSize(width: 320, height: 50)
    }
    super.init()

    guard let placementId = Int64(params["adUnitId"] as? String ?? "") else {
      plugin?.emit(
        AdEventMessage(
          kind: .failedToLoad, adId: adId, format: .banner, errorCode: "invalidConfig",
          errorMessage: "InMobi placement IDs are numeric"))
      return
    }
    let view = IMBanner(frame: CGRect(origin: .zero, size: size), placementId: placementId)
    view.delegate = self
    view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    NSLayoutConstraint.activate([
      view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      view.widthAnchor.constraint(equalToConstant: size.width),
      view.heightAnchor.constraint(equalToConstant: size.height),
    ])
    banner = view
    view.load()
  }

  deinit {
    banner?.delegate = nil
    banner?.cancel()
    banner?.removeFromSuperview()
  }

  func view() -> UIView { container }

  func bannerDidFinishLoading(_ banner: IMBanner) {
    plugin?.emit(
      AdEventMessage(
        kind: .bannerSized, adId: adId, format: .banner, width: Double(size.width),
        height: Double(size.height)))
    plugin?.emit(AdEventMessage(kind: .loaded, adId: adId, format: .banner))
  }

  func banner(_ banner: IMBanner, didFailToLoadWithError error: IMRequestStatus) {
    let ns = error as NSError
    plugin?.emit(
      AdEventMessage(
        kind: .failedToLoad, adId: adId, format: .banner, errorCode: InmobiErrors.code(ns.code),
        errorMessage: ns.localizedDescription, nativeCode: String(ns.code)))
  }

  func bannerAdImpressed(_ banner: IMBanner) {
    plugin?.emit(AdEventMessage(kind: .impression, adId: adId, format: .banner))
  }

  func banner(_ banner: IMBanner, didInteractWithParams params: [String: Any]?) {
    plugin?.emit(AdEventMessage(kind: .clicked, adId: adId, format: .banner))
  }
}
