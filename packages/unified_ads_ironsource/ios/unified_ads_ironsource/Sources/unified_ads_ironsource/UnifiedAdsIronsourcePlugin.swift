import Flutter
import IronSource
import UIKit

let ironsourceBannerViewType = "dev.arovyx.plugin.unifiedads/ironsource/banner"

/// ironSource / Unity LevelPlay adapter plugin (LevelPlay 9.x APIs only).
public final class UnifiedAdsIronsourcePlugin: NSObject, FlutterPlugin, IronsourceHostApi {
  private let events: IronsourceEventsApi
  private var ads: [String: IronsourceAdHolder] = [:]
  private var counter = 0
  private var initialized = false
  private var pendingEvents: [AdEventMessage] = []
  private var draining = false

  init(messenger: FlutterBinaryMessenger) {
    events = IronsourceEventsApi(binaryMessenger: messenger)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = UnifiedAdsIronsourcePlugin(messenger: registrar.messenger())
    IronsourceHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.register(IronsourceBannerFactory(plugin: instance), withId: ironsourceBannerViewType)
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    IronsourceHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
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

  // MARK: IronsourceHostApi

  func initialize(request: InitRequest) async throws -> InitInfo {
    try await initializeOnMain(request)
  }

  func load(format: AdFormatMessage, adUnitId: String) async throws -> String {
    try await loadOnMain(format: format, adUnitId: adUnitId)
  }

  func show(adId: String) async throws { try await showOnMain(adId: adId) }

  func destroy(adId: String) throws { remove(adId) }

  func applyConsent(consent: ConsentMessage) throws {
    // LevelPlay expects these before init; IAB TCF strings are also read automatically.
    if let given = consent.consentGiven { LPMPrivacySettings.setGDPRConsent(given) }
    if let optOut = consent.ccpaOptOut { LPMPrivacySettings.setCCPA(optOut) }
    LPMPrivacySettings.setCOPPA(consent.coppa)
    // Opt-in Meta bidding: privacy reaches Audience Network before LevelPlay
    // initializes the adapter (consent is applied before init).
    if MetaBidding.detect() != nil {
      MetaBidding.applyPrivacy(ccpaOptOut: consent.ccpaOptOut, coppa: consent.coppa)
      LevelPlay.setMetaData(withKey: "Meta_Mixed_Audience", value: consent.coppa ? "true" : "false")
    }
  }

  func dispose() throws { ads.removeAll() }

  // MARK: Main-actor implementations

  @MainActor
  private func initializeOnMain(_ request: InitRequest) async throws -> InitInfo {
    guard !request.appId.isEmpty else {
      throw PigeonError(code: "invalidConfig", message: "The LevelPlay app key is empty", details: nil)
    }
    if request.testMode {
      NSLog("[unified_ads_ironsource] LevelPlay has no test-ads flag: use the test suite.")
    }
    let info = InitInfo(metaBiddingAdapter: MetaBidding.detect())
    if initialized { return info }
    let builder = LPMInitRequestBuilder(appKey: request.appId)
    if let userId = request.userId { _ = builder.withUserId(userId) }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      LevelPlay.initWith(builder.build()) { _, error in
        if let error {
          let ns = error as NSError
          continuation.resume(
            throwing: PigeonError(
              code: "initializationFailed", message: ns.localizedDescription, details: String(ns.code)))
        } else {
          continuation.resume()
        }
      }
    }
    initialized = true
    return info
  }

  @MainActor
  private func loadOnMain(format: AdFormatMessage, adUnitId: String) async throws -> String {
    if format == .banner {
      throw PigeonError(code: "unsupportedFormat", message: "Banners load through the platform view", details: nil)
    }
    guard initialized else {
      throw PigeonError(code: "notInitialized", message: "LevelPlay is not initialized", details: nil)
    }
    counter += 1
    let holder = IronsourceAdHolder(id: "ironsource-\(counter)", format: format, plugin: self)
    ads[holder.id] = holder
    return try await withCheckedThrowingContinuation { continuation in
      holder.loadContinuation = continuation
      if format == .rewarded {
        let ad = LPMRewardedAd(adUnitId: adUnitId)
        holder.rewarded = ad
        ad.setDelegate(holder)
        ad.loadAd()
      } else {
        let ad = LPMInterstitialAd(adUnitId: adUnitId)
        holder.interstitial = ad
        ad.setDelegate(holder)
        ad.loadAd()
      }
    }
  }

  @MainActor
  private func showOnMain(adId: String) async throws {
    guard let holder = ads[adId] else {
      throw PigeonError(code: "notReady", message: "No loaded LevelPlay ad with id \(adId)", details: nil)
    }
    guard let viewController = Self.topViewController() else {
      throw PigeonError(code: "noActivity", message: "No view controller to present the ad", details: nil)
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      holder.showContinuation = continuation
      holder.interstitial?.showAd(viewController: viewController, placementName: nil)
      holder.rewarded?.showAd(viewController: viewController, placementName: nil)
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

/// LevelPlay error codes (ISError.h) → `AdErrorCode` names.
enum IronsourceErrors {
  static func loadCode(_ code: Int) -> String {
    switch code {
    case 509, 606, 1024, 1035, 1044, 1158: return "noFill"
    case 520: return "networkError"
    case 524, 525, 526, 530: return "frequencyCapped"
    case 624, 626: return "invalidConfig"
    case 625: return "notInitialized"
    case 627, 629: return "alreadyShowing"
    default: return "internal"
    }
  }

  static func showCode(_ code: Int) -> String {
    switch code {
    case 628: return "notReady"
    case 630: return "alreadyShowing"
    case 631, 632: return "noActivity"  // show with nil (view) controller
    case 524, 525, 526, 530: return "frequencyCapped"
    default: return "showFailed"
    }
  }
}

/// One loaded LevelPlay interstitial / rewarded ad and its delegate.
final class IronsourceAdHolder: NSObject, LPMInterstitialAdDelegate, LPMRewardedAdDelegate {
  let id: String
  let format: AdFormatMessage
  var interstitial: LPMInterstitialAd?
  var rewarded: LPMRewardedAd?
  var loadContinuation: CheckedContinuation<String, Error>?
  var showContinuation: CheckedContinuation<Void, Error>?
  private weak var plugin: UnifiedAdsIronsourcePlugin?

  init(id: String, format: AdFormatMessage, plugin: UnifiedAdsIronsourcePlugin) {
    self.id = id
    self.format = format
    self.plugin = plugin
  }

  private func send(_ kind: AdEventKind) {
    plugin?.emit(AdEventMessage(kind: kind, adId: id, format: format))
  }

  func didLoadAd(with adInfo: LPMAdInfo) {
    send(.loaded)
    loadContinuation?.resume(returning: id)
    loadContinuation = nil
  }

  func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
    plugin?.remove(id)
    let ns = error as NSError
    loadContinuation?.resume(
      throwing: PigeonError(
        code: IronsourceErrors.loadCode(ns.code), message: ns.localizedDescription, details: String(ns.code)))
    loadContinuation = nil
  }

  func didDisplayAd(with adInfo: LPMAdInfo) {
    send(.shown)
    send(.impression)
    showContinuation?.resume()
    showContinuation = nil
  }

  func didFailToDisplayAd(with adInfo: LPMAdInfo, error: Error) {
    let ns = error as NSError
    let code = IronsourceErrors.showCode(ns.code)
    plugin?.emit(
      AdEventMessage(
        kind: .failedToShow, adId: id, format: format, errorCode: code,
        errorMessage: ns.localizedDescription, nativeCode: String(ns.code)))
    showContinuation?.resume(
      throwing: PigeonError(code: code, message: ns.localizedDescription, details: String(ns.code)))
    showContinuation = nil
    plugin?.remove(id)
  }

  func didClickAd(with adInfo: LPMAdInfo) { send(.clicked) }

  func didCloseAd(with adInfo: LPMAdInfo) {
    send(.closed)
    plugin?.remove(id)
  }

  /// May arrive after close; the Dart side accepts a late reward.
  func didRewardAd(with adInfo: LPMAdInfo, reward: LPMReward) {
    plugin?.emit(
      AdEventMessage(
        kind: .earnedReward, adId: id, format: format, rewardAmount: Double(reward.amount),
        rewardType: reward.name))
  }
}
