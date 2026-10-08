import Flutter
import InMobiSDK
import UIKit

let inmobiBannerViewType = "dev.arovyx.plugin.unifiedads/inmobi/banner"

/// InMobi adapter plugin. Interstitial and rewarded ads both use
/// `IMInterstitial` (a rewarded placement unlocks rewards).
public final class UnifiedAdsInmobiPlugin: NSObject, FlutterPlugin, InmobiHostApi {
  private let events: InmobiEventsApi
  private var ads: [String: InmobiAdHolder] = [:]
  private var counter = 0
  private var initialized = false
  private var pendingEvents: [AdEventMessage] = []
  private var draining = false

  init(messenger: FlutterBinaryMessenger) {
    events = InmobiEventsApi(binaryMessenger: messenger)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = UnifiedAdsInmobiPlugin(messenger: registrar.messenger())
    InmobiHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.register(InmobiBannerFactory(plugin: instance), withId: inmobiBannerViewType)
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    InmobiHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
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

  // MARK: InmobiHostApi

  func initialize(request: InitRequest) async throws { try await initializeOnMain(request) }

  func load(format: AdFormatMessage, adUnitId: String) async throws -> String {
    try await loadOnMain(format: format, adUnitId: adUnitId)
  }

  func show(adId: String) async throws { try await showOnMain(adId: adId) }

  func destroy(adId: String) throws { remove(adId) }

  func applyConsent(consent: ConsentMessage) throws {
    IMSdk.setIsAgeRestricted(consent.coppa)
    if let optOut = consent.ccpaOptOut { IMPrivacyCompliance.setDoNotSell(optOut) }
    // With a CMP (e.g. UMP) InMobi reads the IAB TCF string itself (10.7.5+).
    if let given = consent.consentGiven {
      IMSdk.updateGDPRConsent([IMCommonConstants.IM_GDPR_CONSENT_AVAILABLE: given ? "true" : "false"])
    }
  }

  func dispose() throws { ads.removeAll() }

  // MARK: Main-actor implementations

  @MainActor
  private func initializeOnMain(_ request: InitRequest) async throws {
    guard !request.appId.isEmpty else {
      throw PigeonError(code: "invalidConfig", message: "The InMobi account ID is empty", details: nil)
    }
    // Test ads are configured per placement in the InMobi dashboard; debug
    // logging prints the device ID for "Selective" test mode.
    if request.testMode { IMSdk.setLogLevel(.debug) }
    if initialized { return }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      IMSdk.initWithAccountID(request.appId, andCompletionHandler: { error in
        if let error {
          continuation.resume(
            throwing: PigeonError(code: "initializationFailed", message: error.localizedDescription, details: nil))
        } else {
          continuation.resume()
        }
      })
    }
    initialized = true
  }

  @MainActor
  private func loadOnMain(format: AdFormatMessage, adUnitId: String) async throws -> String {
    if format == .banner {
      throw PigeonError(code: "unsupportedFormat", message: "Banners load through the platform view", details: nil)
    }
    guard let placementId = Int64(adUnitId) else {
      throw PigeonError(code: "invalidConfig", message: "InMobi placement IDs are numeric: '\(adUnitId)'", details: nil)
    }
    counter += 1
    let holder = InmobiAdHolder(id: "inmobi-\(counter)", format: format, plugin: self)
    ads[holder.id] = holder
    return try await withCheckedThrowingContinuation { continuation in
      holder.loadContinuation = continuation
      let ad = IMInterstitial(placementId: placementId, delegate: holder)
      holder.ad = ad
      ad.load()
    }
  }

  @MainActor
  private func showOnMain(adId: String) async throws {
    guard let holder = ads[adId], let ad = holder.ad, ad.isReady() else {
      throw PigeonError(code: "notReady", message: "InMobi ad \(adId) is not ready", details: nil)
    }
    guard let viewController = Self.topViewController() else {
      throw PigeonError(code: "noActivity", message: "No view controller to present the ad", details: nil)
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      holder.showContinuation = continuation
      ad.show(from: viewController)
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

/// `IMStatusCode` raw value → `AdErrorCode` name (raw values from the 11.5.0
/// swiftinterface enum order; ⚠ only 22/23 are explicit there).
enum InmobiErrors {
  static func code(_ raw: Int) -> String {
    switch raw {
    case 1: return "noFill"
    case 0, 7: return "networkError"  // networkUnReachable, serverError
    case 4: return "timeout"
    case 2, 11, 13: return "invalidConfig"  // requestInvalid, incorrectPlacementID, invalidBannerframe
    case 8: return "alreadyShowing"  // adActive
    case 12: return "notInitialized"  // sdkNotInitialised
    default: return "internal"
    }
  }

  static func error(_ status: IMRequestStatus) -> PigeonError {
    let ns = status as NSError
    return PigeonError(code: code(ns.code), message: ns.localizedDescription, details: String(ns.code))
  }
}

/// One loaded InMobi interstitial / rewarded ad and its delegate.
final class InmobiAdHolder: NSObject, IMInterstitialDelegate {
  let id: String
  let format: AdFormatMessage
  var ad: IMInterstitial?
  var loadContinuation: CheckedContinuation<String, Error>?
  var showContinuation: CheckedContinuation<Void, Error>?
  private weak var plugin: UnifiedAdsInmobiPlugin?

  init(id: String, format: AdFormatMessage, plugin: UnifiedAdsInmobiPlugin) {
    self.id = id
    self.format = format
    self.plugin = plugin
  }

  private func send(_ kind: AdEventKind) {
    plugin?.emit(AdEventMessage(kind: kind, adId: id, format: format))
  }

  func interstitialDidFinishLoading(_ interstitial: IMInterstitial) {
    send(.loaded)
    loadContinuation?.resume(returning: id)
    loadContinuation = nil
  }

  func interstitial(_ interstitial: IMInterstitial, didFailToLoadWithError error: IMRequestStatus) {
    plugin?.remove(id)
    loadContinuation?.resume(throwing: InmobiErrors.error(error))
    loadContinuation = nil
  }

  func interstitialDidPresent(_ interstitial: IMInterstitial) {
    send(.shown)
    showContinuation?.resume()
    showContinuation = nil
  }

  func interstitial(_ interstitial: IMInterstitial, didFailToPresentWithError error: IMRequestStatus) {
    let failure = InmobiErrors.error(error)
    plugin?.emit(
      AdEventMessage(
        kind: .failedToShow, adId: id, format: format, errorCode: "showFailed",
        errorMessage: failure.message, nativeCode: failure.details as? String))
    showContinuation?.resume(throwing: PigeonError(code: "showFailed", message: failure.message, details: failure.details))
    showContinuation = nil
    plugin?.remove(id)
  }

  func interstitialAdImpressed(_ interstitial: IMInterstitial) { send(.impression) }

  func interstitial(_ interstitial: IMInterstitial, didInteractWithParams params: [String: Any]?) {
    send(.clicked)
  }

  func interstitialDidDismiss(_ interstitial: IMInterstitial) {
    send(.closed)
    plugin?.remove(id)
  }

  func interstitial(_ interstitial: IMInterstitial, rewardActionCompletedWithRewards rewards: [String: Any]) {
    let first = rewards.first
    let amount = (first?.value as? NSNumber)?.doubleValue ?? Double("\(first?.value ?? "")") ?? 1
    plugin?.emit(
      AdEventMessage(
        kind: .earnedReward, adId: id, format: format, rewardAmount: amount,
        rewardType: first?.key ?? "reward"))
  }
}
