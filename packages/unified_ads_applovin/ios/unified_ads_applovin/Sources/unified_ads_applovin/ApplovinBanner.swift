import AppLovinSDK
import Flutter
import UIKit

final class ApplovinBannerFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: UnifiedAdsApplovinPlugin?

  init(plugin: UnifiedAdsApplovinPlugin) { self.plugin = plugin }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    ApplovinBannerView(frame: frame, params: args as? [String: Any] ?? [:], plugin: plugin)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A MAX banner / MREC (`MAAdView`) in a Flutter platform view.
final class ApplovinBannerView: NSObject, FlutterPlatformView, MAAdViewAdDelegate, MAAdRevenueDelegate {
  private let container: UIView
  private let adId: String
  private var adView: MAAdView?
  private weak var plugin: UnifiedAdsApplovinPlugin?

  init(frame: CGRect, params: [String: Any], plugin: UnifiedAdsApplovinPlugin?) {
    container = UIView(frame: frame)
    adId = params["adId"] as? String ?? ""
    self.plugin = plugin
    super.init()

    let size = params["size"] as? [String: Any]
    let unit = params["adUnitId"] as? String ?? ""
    let width = CGFloat((size?["width"] as? NSNumber)?.doubleValue ?? Double(UIScreen.main.bounds.width))
    let view: MAAdView
    switch size?["type"] as? String {
    case "mediumRectangle":
      view = MAAdView(adUnitIdentifier: unit, adFormat: .mrec)
    case "leaderboard":
      view = MAAdView(adUnitIdentifier: unit, adFormat: .leader)
    case "adaptiveAnchored", "adaptiveInline":
      // ⚠ Swift spelling of the MAAdViewConfiguration builder (verify in CI).
      let inline = size?["type"] as? String == "adaptiveInline"
      let maxHeight = (size?["maxHeight"] as? NSNumber).map { CGFloat($0.doubleValue) }
      let configuration = MAAdViewConfiguration { builder in
        builder.adaptiveType = inline ? .inline : .anchored
        builder.adaptiveWidth = width
        if let maxHeight { builder.inlineMaximumHeight = maxHeight }
      }
      view = MAAdView(adUnitIdentifier: unit, configuration: configuration)
    default:
      view = MAAdView(adUnitIdentifier: unit, adFormat: .banner)
    }
    view.delegate = self
    view.revenueDelegate = self
    view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      view.topAnchor.constraint(equalTo: container.topAnchor),
      view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    adView = view
    view.loadAd()
  }

  deinit {
    adView?.delegate = nil
    adView?.revenueDelegate = nil
    adView?.stopAutoRefresh()
    adView?.removeFromSuperview()
  }

  func view() -> UIView { container }

  private func send(_ kind: AdEventKind) {
    plugin?.emit(AdEventMessage(kind: kind, adId: adId, format: .banner))
  }

  func didLoad(_ ad: MAAd) {
    plugin?.emit(
      AdEventMessage(
        kind: .bannerSized, adId: adId, format: .banner, width: Double(ad.size.width),
        height: Double(ad.size.height)))
    send(.loaded)
  }

  func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
    let code = error.code.rawValue
    plugin?.emit(
      AdEventMessage(
        kind: .failedToLoad, adId: adId, format: .banner, errorCode: ApplovinErrors.loadCode(code),
        errorMessage: error.message, nativeCode: String(code)))
  }

  func didClick(_ ad: MAAd) { send(.clicked) }
  func didPayRevenue(for ad: MAAd) { send(.impression) }
  func didDisplay(_ ad: MAAd) {}
  func didHide(_ ad: MAAd) {}
  func didFail(toDisplay ad: MAAd, withError error: MAError) {}
  func didExpand(_ ad: MAAd) {}
  func didCollapse(_ ad: MAAd) {}
}
