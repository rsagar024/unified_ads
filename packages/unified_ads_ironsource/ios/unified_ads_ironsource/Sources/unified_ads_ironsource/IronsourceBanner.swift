import Flutter
import IronSource
import UIKit

final class IronsourceBannerFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: UnifiedAdsIronsourcePlugin?

  init(plugin: UnifiedAdsIronsourcePlugin) { self.plugin = plugin }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    IronsourceBannerView(frame: frame, params: args as? [String: Any] ?? [:], plugin: plugin)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// An `LPMBannerAdView` in a Flutter platform view.
final class IronsourceBannerView: NSObject, FlutterPlatformView, LPMBannerAdViewDelegate {
  private let container: UIView
  private let adId: String
  private var banner: LPMBannerAdView?
  private weak var plugin: UnifiedAdsIronsourcePlugin?

  init(frame: CGRect, params: [String: Any], plugin: UnifiedAdsIronsourcePlugin?) {
    container = UIView(frame: frame)
    adId = params["adId"] as? String ?? ""
    self.plugin = plugin
    super.init()

    // Swift imports the 9.7.0 `LPMAdSize.h` factories (`bannerSize`,
    // `largeSize`, `createAdaptiveAdSizeWithWidth:`, …) without the "Size"
    // suffix; `banner()` and `createAdaptive()` are confirmed by the official demo.
    let adSize: LPMAdSize
    switch (params["size"] as? [String: Any])?["type"] as? String {
    case "largeBanner": adSize = LPMAdSize.large()
    case "mediumRectangle": adSize = LPMAdSize.mediumRectangle()
    case "leaderboard": adSize = LPMAdSize.leaderBoard()
    case "adaptiveAnchored", "adaptiveInline":
      // Width ≤ 0 makes the SDK use the screen width, as Android does.
      let width = ((params["size"] as? [String: Any])?["width"] as? NSNumber)?.doubleValue ?? 0
      adSize = LPMAdSize.createAdaptive(withWidth: CGFloat(width)) ?? LPMAdSize.banner()
    default: adSize = LPMAdSize.banner()
    }
    let config = LPMBannerAdViewConfigBuilder().set(adSize: adSize).build()
    let view = LPMBannerAdView(adUnitId: params["adUnitId"] as? String ?? "", config: config)
    view.setDelegate(self)
    view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    NSLayoutConstraint.activate([
      view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      view.widthAnchor.constraint(equalToConstant: CGFloat(adSize.width)),
      view.heightAnchor.constraint(equalToConstant: CGFloat(adSize.height)),
    ])
    banner = view
    if let viewController = UnifiedAdsIronsourcePlugin.topViewController() {
      view.loadAd(with: viewController)
    } else {
      plugin?.emit(
        AdEventMessage(
          kind: .failedToLoad, adId: adId, format: .banner, errorCode: "noActivity",
          errorMessage: "No view controller for the LevelPlay banner"))
    }
  }

  deinit {
    banner?.destroy()
    banner?.removeFromSuperview()
  }

  func view() -> UIView { container }

  func didLoadAd(with adInfo: LPMAdInfo) {
    if let size = adInfo.adSize {
      plugin?.emit(
        AdEventMessage(
          kind: .bannerSized, adId: adId, format: .banner, width: Double(size.width),
          height: Double(size.height)))
    }
    plugin?.emit(AdEventMessage(kind: .loaded, adId: adId, format: .banner))
  }

  func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
    let ns = error as NSError
    plugin?.emit(
      AdEventMessage(
        kind: .failedToLoad, adId: adId, format: .banner, errorCode: IronsourceErrors.loadCode(ns.code),
        errorMessage: ns.localizedDescription, nativeCode: String(ns.code)))
  }

  func didDisplayAd(with adInfo: LPMAdInfo) {
    plugin?.emit(AdEventMessage(kind: .impression, adId: adId, format: .banner))
  }

  func didClickAd(with adInfo: LPMAdInfo) {
    plugin?.emit(AdEventMessage(kind: .clicked, adId: adId, format: .banner))
  }
}
