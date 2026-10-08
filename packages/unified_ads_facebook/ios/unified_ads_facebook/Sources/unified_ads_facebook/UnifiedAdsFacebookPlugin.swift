import FBAudienceNetwork
import Flutter
import UIKit

let facebookBannerViewType = "dev.arovyx.plugin.unifiedads/facebook/banner"

/// Facebook Audience Network (Meta) adapter plugin.
///
/// Audience Network is bidding-only: `loadAd` is deprecated in 6.22 in favour
/// of `loadAdWithBidPayload:`. This direct integration serves test ads but is
/// not expected to fill in production. Names are taken from the
/// FBAudienceNetwork 6.22.0 headers.
public final class UnifiedAdsFacebookPlugin: NSObject, FlutterPlugin, FacebookHostApi {
  private let events: FacebookEventsApi
  private var ads: [String: FacebookAdHolder] = [:]
  private var counter = 0
  private var initialized = false
  private var pendingEvents: [AdEventMessage] = []
  private var draining = false

  init(messenger: FlutterBinaryMessenger) {
    events = FacebookEventsApi(binaryMessenger: messenger)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = UnifiedAdsFacebookPlugin(messenger: registrar.messenger())
    FacebookHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.register(FacebookBannerFactory(plugin: instance), withId: facebookBannerViewType)
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    FacebookHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    try? dispose()
  }

  func emit(_ event: AdEventMessage) {
    DispatchQueue.main.async {
      self.pendingEvents.append(event)
      guard !self.draining else { return }
      self.draining = true
      Task { @MainActor in
        while !self.pendingEvents.isEmpty {
          let next = self.pendingEvents.removeFirst()
          try? await self.events.onAdEvent(event: next)
        }
        self.draining = false
      }
    }
  }

  func remove(_ id: String) { ads.removeValue(forKey: id) }

  // MARK: FacebookHostApi

  func initialize(request: InitRequest) async throws { try await initializeOnMain(request) }

  func load(format: AdFormatMessage, adUnitId: String) async throws -> String {
    try await loadOnMain(format: format, adUnitId: adUnitId)
  }

  func show(adId: String) async throws { try await showOnMain(adId: adId) }

  func destroy(adId: String) throws { remove(adId) }

  func applyConsent(consent: ConsentMessage) throws {
    // US privacy: Limited Data Use (country/state 0 = geolocate).
    switch consent.ccpaOptOut {
    case .some(true): FBAdSettings.setDataProcessingOptions(["LDU"], country: 0, state: 0)
    case .some(false): FBAdSettings.setDataProcessingOptions([])
    case .none: break
    }
    FBAdSettings.mixedAudience = consent.coppa
    // ATT: on iOS 17+ with SDK 6.15+ the SDK reads ATTrackingManager itself;
    // the deprecated setAdvertiserTrackingEnabled: is not used.
  }

  func dispose() throws { ads.removeAll() }

  // MARK: Main-actor implementations

  @MainActor
  private func initializeOnMain(_ request: InitRequest) async throws {
    if request.testMode && !request.testDeviceIds.isEmpty {
      FBAdSettings.addTestDevices(request.testDeviceIds)
    }
    if initialized { return }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      FBAudienceNetworkAds.initialize(with: nil) { results in
        if results.isSuccess {
          continuation.resume()
        } else {
          continuation.resume(
            throwing: PigeonError(code: "initializationFailed", message: results.message, details: nil))
        }
      }
    }
    initialized = true
  }

  @MainActor
  private func loadOnMain(format: AdFormatMessage, adUnitId: String) async throws -> String {
    if format == .banner {
      throw PigeonError(code: "unsupportedFormat", message: "Banners load through the platform view", details: nil)
    }
    counter += 1
    let holder = FacebookAdHolder(id: "facebook-\(counter)", format: format, plugin: self)
    ads[holder.id] = holder
    return try await withCheckedThrowingContinuation { continuation in
      holder.loadContinuation = continuation
      if format == .rewarded {
        let ad = FBRewardedVideoAd(placementID: adUnitId)
        holder.rewarded = ad
        ad.delegate = holder
        ad.loadAd()  // deprecated in 6.22 (bidding-only); still the direct path
      } else {
        let ad = FBInterstitialAd(placementID: adUnitId)
        holder.interstitial = ad
        ad.delegate = holder
        ad.loadAd()
      }
    }
  }

  @MainActor
  private func showOnMain(adId: String) async throws {
    guard let holder = ads[adId] else {
      throw PigeonError(code: "notReady", message: "No loaded Audience Network ad with id \(adId)", details: nil)
    }
    guard let viewController = Self.topViewController() else {
      throw PigeonError(code: "noActivity", message: "No view controller to present the ad", details: nil)
    }
    if holder.interstitial?.isAdValid == false || holder.rewarded?.isAdValid == false {
      remove(adId)
      throw PigeonError(code: "notReady", message: "Audience Network ad \(adId) expired", details: nil)
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      holder.showContinuation = continuation
      let accepted =
        holder.interstitial?.showAd(fromRootViewController: viewController)
        ?? holder.rewarded?.showAd(fromRootViewController: viewController) ?? false
      if !accepted, holder.showContinuation != nil {
        holder.showContinuation = nil
        remove(adId)
        continuation.resume(
          throwing: PigeonError(code: "showFailed", message: "Audience Network refused to show the ad", details: nil))
      }
    }
  }

  static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

/// Audience Network error code → `AdErrorCode` name (same codes as Android).
enum FacebookErrors {
  static func loadCode(_ code: Int) -> String {
    switch code {
    case 1001: return "noFill"
    case 1000, 2000: return "networkError"
    case 1002: return "frequencyCapped"
    case 2009: return "timeout"
    case 7003, 7005, 7006, 1011, 1203: return "invalidConfig"
    case 7002: return "alreadyShowing"
    default: return "internal"
    }
  }

  static func showCode(_ code: Int) -> String {
    switch code {
    case 7001, 7004: return "notReady"
    default: return "showFailed"
    }
  }
}

/// One loaded interstitial / rewarded video ad and its delegate.
final class FacebookAdHolder: NSObject, FBInterstitialAdDelegate, FBRewardedVideoAdDelegate {
  let id: String
  let format: AdFormatMessage
  var interstitial: FBInterstitialAd?
  var rewarded: FBRewardedVideoAd?
  var loadContinuation: CheckedContinuation<String, Error>?
  var showContinuation: CheckedContinuation<Void, Error>?
  private var shown = false
  private weak var plugin: UnifiedAdsFacebookPlugin?

  init(id: String, format: AdFormatMessage, plugin: UnifiedAdsFacebookPlugin) {
    self.id = id
    self.format = format
    self.plugin = plugin
  }

  private func send(_ kind: AdEventKind) {
    plugin?.emit(AdEventMessage(kind: kind, adId: id, format: format))
  }

  private func loaded() {
    send(.loaded)
    loadContinuation?.resume(returning: id)
    loadContinuation = nil
  }

  private func failed(_ error: Error) {
    let ns = error as NSError
    if let load = loadContinuation {
      loadContinuation = nil
      plugin?.remove(id)
      load.resume(
        throwing: PigeonError(
          code: FacebookErrors.loadCode(ns.code), message: ns.localizedDescription, details: String(ns.code)))
      return
    }
    let code = FacebookErrors.showCode(ns.code)
    plugin?.emit(
      AdEventMessage(
        kind: .failedToShow, adId: id, format: format, errorCode: code,
        errorMessage: ns.localizedDescription, nativeCode: String(ns.code)))
    showContinuation?.resume(
      throwing: PigeonError(code: code, message: ns.localizedDescription, details: String(ns.code)))
    showContinuation = nil
    plugin?.remove(id)
  }

  /// The impression marks the presentation (there is no "did present" callback).
  private func impression() {
    if !shown {
      shown = true
      send(.shown)
      showContinuation?.resume()
      showContinuation = nil
    }
    send(.impression)
  }

  private func closed() {
    send(.closed)
    plugin?.remove(id)
  }

  // FBInterstitialAdDelegate
  func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) { loaded() }
  func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) { failed(error) }
  func interstitialAdWillLogImpression(_ interstitialAd: FBInterstitialAd) { impression() }
  func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) { send(.clicked) }
  func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) { closed() }

  // FBRewardedVideoAdDelegate
  func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) { loaded() }
  func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) { failed(error) }
  func rewardedVideoAdWillLogImpression(_ rewardedVideoAd: FBRewardedVideoAd) { impression() }
  func rewardedVideoAdDidClick(_ rewardedVideoAd: FBRewardedVideoAd) { send(.clicked) }
  /// Audience Network reports completion without an amount/type; Dart fills in
  /// the configured default.
  func rewardedVideoAdVideoComplete(_ rewardedVideoAd: FBRewardedVideoAd) { send(.earnedReward) }
  func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) { closed() }
}
