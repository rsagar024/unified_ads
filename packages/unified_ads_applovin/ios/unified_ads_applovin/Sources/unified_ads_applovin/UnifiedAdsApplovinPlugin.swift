import AppLovinSDK
import Flutter
import UIKit

let applovinBannerViewType = "dev.arovyx.plugin.unifiedads/applovin/banner"

/// AppLovin MAX adapter plugin. Pigeon calls the async host methods from a
/// `@MainActor` task; each delegates to a `@MainActor` implementation.
public final class UnifiedAdsApplovinPlugin: NSObject, FlutterPlugin, ApplovinHostApi {
  private let events: ApplovinEventsApi
  private var ads: [String: ApplovinAdHolder] = [:]
  /// MAX rewarded ads are singletons per ad unit: the holder bound to each unit.
  private var rewardedByUnit: [String: ApplovinAdHolder] = [:]
  private var counter = 0
  private var initialized = false
  private var coppa = false
  private var pendingEvents: [AdEventMessage] = []
  private var draining = false

  init(messenger: FlutterBinaryMessenger) {
    events = ApplovinEventsApi(binaryMessenger: messenger)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = UnifiedAdsApplovinPlugin(messenger: registrar.messenger())
    ApplovinHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.register(ApplovinBannerFactory(plugin: instance), withId: applovinBannerViewType)
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    ApplovinHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    try? dispose()
  }

  /// Sends events to Dart in order, one at a time, on the main thread.
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

  func release(_ holder: ApplovinAdHolder) {
    ads.removeValue(forKey: holder.id)
    holder.interstitial?.delegate = nil
    holder.interstitial?.revenueDelegate = nil
    holder.interstitial = nil
    holder.appOpen?.delegate = nil
    holder.appOpen?.revenueDelegate = nil
    holder.appOpen = nil
    if rewardedByUnit[holder.adUnitId] === holder {
      rewardedByUnit.removeValue(forKey: holder.adUnitId)
    }
    holder.rewarded = nil
  }

  // MARK: ApplovinHostApi

  func initialize(request: InitRequest) async throws -> InitInfo {
    try await initializeOnMain(request)
  }

  func load(format: AdFormatMessage, adUnitId: String) async throws -> String {
    try await loadOnMain(format: format, adUnitId: adUnitId)
  }

  func show(adId: String) async throws { try await showOnMain(adId: adId) }

  func destroy(adId: String) throws {
    if let holder = ads[adId] { release(holder) }
  }

  func applyConsent(consent: ConsentMessage) throws {
    coppa = consent.coppa
    // MAX requires these before initialization.
    if let given = consent.consentGiven { ALPrivacySettings.setHasUserConsent(given) }
    if let optOut = consent.ccpaOptOut { ALPrivacySettings.setDoNotSell(optOut) }
    // Opt-in Meta bidding: privacy reaches Audience Network before MAX
    // initializes the adapter (consent is applied before init).
    if MetaBidding.detect() != nil {
      MetaBidding.applyPrivacy(ccpaOptOut: consent.ccpaOptOut, coppa: consent.coppa)
    }
  }

  func dispose() throws {
    ads.values.forEach { release($0) }
    ads.removeAll()
    rewardedByUnit.removeAll()
  }

  // MARK: Main-actor implementations

  @MainActor
  private func initializeOnMain(_ request: InitRequest) async throws -> InitInfo {
    guard !request.appId.isEmpty else {
      throw PigeonError(code: "invalidConfig", message: "The AppLovin MAX SDK key is empty", details: nil)
    }
    if coppa {
      throw PigeonError(
        code: "configConflict",
        message: "AppLovin MAX must not be initialized for child-directed users", details: nil)
    }
    let info = InitInfo(metaBiddingAdapter: MetaBidding.detect())
    if initialized { return info }
    let testIds = request.testMode ? request.testDeviceIds : []
    let configuration = ALSdkInitializationConfiguration(sdkKey: request.appId) { builder in
      builder.mediationProvider = ALMediationProviderMAX
      builder.testDeviceAdvertisingIdentifiers = testIds
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      ALSdk.shared().initialize(with: configuration) { _ in continuation.resume() }
    }
    initialized = true
    return info
  }

  @MainActor
  private func loadOnMain(format: AdFormatMessage, adUnitId: String) async throws -> String {
    if format == .banner {
      throw PigeonError(code: "unsupportedFormat", message: "Banners load through the platform view", details: nil)
    }
    counter += 1
    let holder = ApplovinAdHolder(id: "applovin-\(counter)", format: format, adUnitId: adUnitId, plugin: self)
    ads[holder.id] = holder
    return try await withCheckedThrowingContinuation { continuation in
      holder.loadContinuation = continuation
      if format == .rewarded {
        let ad = MARewardedAd.shared(withAdUnitIdentifier: adUnitId)
        if let previous = rewardedByUnit[adUnitId] { ads.removeValue(forKey: previous.id) }
        rewardedByUnit[adUnitId] = holder
        holder.rewarded = ad
        ad.delegate = holder
        ad.revenueDelegate = holder
        ad.load()
      } else if format == .appOpen {
        let ad = MAAppOpenAd(adUnitIdentifier: adUnitId)
        holder.appOpen = ad
        ad.delegate = holder
        ad.revenueDelegate = holder
        ad.load()
      } else {
        let ad = MAInterstitialAd(adUnitIdentifier: adUnitId)
        holder.interstitial = ad
        ad.delegate = holder
        ad.revenueDelegate = holder
        ad.load()
      }
    }
  }

  @MainActor
  private func showOnMain(adId: String) async throws {
    guard let holder = ads[adId] else {
      throw PigeonError(code: "notReady", message: "No loaded AppLovin ad with id \(adId)", details: nil)
    }
    guard let viewController = Self.topViewController() else {
      throw PigeonError(code: "noActivity", message: "No view controller to present the ad", details: nil)
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      holder.showContinuation = continuation
      holder.interstitial?.show(forPlacement: nil, customData: nil, viewController: viewController)
      holder.rewarded?.show(forPlacement: nil, customData: nil, viewController: viewController)
      // MAX presents app open ads from its own window; no view controller.
      holder.appOpen?.showAd()
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

/// MAX error code (`MAErrorCode` raw value) → `AdErrorCode` name.
enum ApplovinErrors {
  static func loadCode(_ code: Int) -> String {
    switch code {
    case 204: return "noFill"
    case -1000, -1009: return "networkError"
    case -1001: return "timeout"
    case -5603: return "invalidConfig"
    default: return "internal"
    }
  }

  static func showCode(_ code: Int) -> String {
    switch code {
    case -23: return "alreadyShowing"
    case -24: return "notReady"
    case -25: return "noActivity"  // fullscreenAdInvalidViewController
    default: return "showFailed"
    }
  }
}

/// One loaded MAX full-screen ad and its delegates.
final class ApplovinAdHolder: NSObject, MARewardedAdDelegate, MAAdRevenueDelegate {
  let id: String
  let format: AdFormatMessage
  let adUnitId: String
  var interstitial: MAInterstitialAd?
  var rewarded: MARewardedAd?
  var appOpen: MAAppOpenAd?
  var loadContinuation: CheckedContinuation<String, Error>?
  var showContinuation: CheckedContinuation<Void, Error>?
  private weak var plugin: UnifiedAdsApplovinPlugin?

  init(id: String, format: AdFormatMessage, adUnitId: String, plugin: UnifiedAdsApplovinPlugin) {
    self.id = id
    self.format = format
    self.adUnitId = adUnitId
    self.plugin = plugin
  }

  private func send(_ kind: AdEventKind) {
    plugin?.emit(AdEventMessage(kind: kind, adId: id, format: format))
  }

  func didLoad(_ ad: MAAd) {
    send(.loaded)
    loadContinuation?.resume(returning: id)
    loadContinuation = nil
  }

  func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
    plugin?.release(self)
    let code = error.code.rawValue
    loadContinuation?.resume(
      throwing: PigeonError(code: ApplovinErrors.loadCode(code), message: error.message, details: String(code)))
    loadContinuation = nil
  }

  func didDisplay(_ ad: MAAd) {
    send(.shown)
    showContinuation?.resume()
    showContinuation = nil
  }

  func didFail(toDisplay ad: MAAd, withError error: MAError) {
    let code = error.code.rawValue
    let failure = PigeonError(code: ApplovinErrors.showCode(code), message: error.message, details: String(code))
    plugin?.emit(
      AdEventMessage(
        kind: .failedToShow, adId: id, format: format, errorCode: failure.code,
        errorMessage: failure.message, nativeCode: String(code)))
    showContinuation?.resume(throwing: failure)
    showContinuation = nil
    plugin?.release(self)
  }

  func didClick(_ ad: MAAd) { send(.clicked) }

  func didHide(_ ad: MAAd) {
    send(.closed)
    plugin?.release(self)
  }

  func didRewardUser(for ad: MAAd, with reward: MAReward) {
    plugin?.emit(
      AdEventMessage(
        kind: .earnedReward, adId: id, format: format, rewardAmount: Double(reward.amount),
        rewardType: reward.label))
  }

  /// MAX reports revenue once per impression: used as the impression event.
  func didPayRevenue(for ad: MAAd) { send(.impression) }
}
