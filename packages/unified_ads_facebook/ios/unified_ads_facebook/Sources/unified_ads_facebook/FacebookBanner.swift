import FBAudienceNetwork
import Flutter
import UIKit

final class FacebookBannerFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: UnifiedAdsFacebookPlugin?

  init(plugin: UnifiedAdsFacebookPlugin) { self.plugin = plugin }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    FacebookBannerView(frame: frame, params: args as? [String: Any] ?? [:], plugin: plugin)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// An Audience Network `FBAdView` in a Flutter platform view: full width with a
/// fixed height of 50 (standard / adaptive), 90 (large / leaderboard) or 250
/// (medium rectangle).
final class FacebookBannerView: NSObject, FlutterPlatformView, FBAdViewDelegate {
  private let container: UIView
  private let adId: String
  private let adSize: FBAdSize
  private var adView: FBAdView?
  private weak var plugin: UnifiedAdsFacebookPlugin?

  init(frame: CGRect, params: [String: Any], plugin: UnifiedAdsFacebookPlugin?) {
    container = UIView(frame: frame)
    adId = params["adId"] as? String ?? ""
    self.plugin = plugin
    switch (params["size"] as? [String: Any])?["type"] as? String {
    case "mediumRectangle": adSize = kFBAdSizeHeight250Rectangle
    case "largeBanner", "leaderboard": adSize = kFBAdSizeHeight90Banner
    default: adSize = kFBAdSizeHeight50Banner
    }
    super.init()

    let view = FBAdView(
      placementID: params["adUnitId"] as? String ?? "", adSize: adSize,
      rootViewController: UnifiedAdsFacebookPlugin.topViewController())
    view.delegate = self
    view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      view.topAnchor.constraint(equalTo: container.topAnchor),
      view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    adView = view
    view.loadAd()  // deprecated in 6.22 (bidding-only); still the direct path
  }

  deinit {
    adView?.delegate = nil
    adView?.removeFromSuperview()
  }

  func view() -> UIView { container }

  func adViewDidLoad(_ adView: FBAdView) {
    // Width -1 in FBAdSize means "flexible": report the container width.
    let width = adSize.size.width > 0 ? adSize.size.width : container.bounds.width
    plugin?.emit(
      AdEventMessage(
        kind: .bannerSized, adId: adId, format: .banner, width: Double(width),
        height: Double(adSize.size.height)))
    plugin?.emit(AdEventMessage(kind: .loaded, adId: adId, format: .banner))
  }

  func adView(_ adView: FBAdView, didFailWithError error: Error) {
    let ns = error as NSError
    plugin?.emit(
      AdEventMessage(
        kind: .failedToLoad, adId: adId, format: .banner, errorCode: FacebookErrors.loadCode(ns.code),
        errorMessage: ns.localizedDescription, nativeCode: String(ns.code)))
  }

  func adViewWillLogImpression(_ adView: FBAdView) {
    plugin?.emit(AdEventMessage(kind: .impression, adId: adId, format: .banner))
  }

  func adViewDidClick(_ adView: FBAdView) {
    plugin?.emit(AdEventMessage(kind: .clicked, adId: adId, format: .banner))
  }
}
