import Flutter
import StartApp
import UIKit

let startappBannerViewType = "dev.arovyx.plugin.unifiedads/startapp/banner"

/// Start.io adapter plugin. The SDK is Objective-C; delegate methods are
/// pinned to their Objective-C selectors with `@objc(...)` so dispatch does
/// not depend on the importer's Swift renaming; the Swift method names
/// match the SDK's `NS_SWIFT_NAME`s (`didLoad(_:)`, …), which Swift enforces.
/// iOS splash and return ads are no-ops in 4.15 (deprecated by Start.io).
public final class UnifiedAdsStartappPlugin: NSObject, FlutterPlugin, StartappHostApi {
  private let events: StartappEventsApi
  private var ads: [String: StartappAdHolder] = [:]
  private var counter = 0
  private var initialized = false
  private var pendingEvents: [AdEventMessage] = []
  private var draining = false

  init(messenger: FlutterBinaryMessenger) {
    events = StartappEventsApi(binaryMessenger: messenger)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = UnifiedAdsStartappPlugin(messenger: registrar.messenger())
    StartappHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.register(StartappBannerFactory(plugin: instance), withId: startappBannerViewType)
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    StartappHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
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

  // MARK: StartappHostApi

  func initialize(request: InitRequest) async throws { try await initializeOnMain(request) }

  func load(format: AdFormatMessage, adUnitId: String) async throws -> String {
    try await loadOnMain(format: format, adUnitId: adUnitId)
  }

  func show(adId: String) async throws { try await showOnMain(adId: adId) }

  func destroy(adId: String) throws { remove(adId) }

  func applyConsent(consent: ConsentMessage) throws {
    guard let sdk = STAStartAppSDK.sharedInstance() else { return }
    if let given = consent.consentGiven {
      // ⚠ Swift spelling inferred from setUserConsent:forConsentType:withTimestamp:.
      sdk.setUserConsent(given, forConsentType: "pas", withTimestamp: Int(Date().timeIntervalSince1970))
    }
    if let optOut = consent.ccpaOptOut {
      // ⚠ Swift spelling inferred from handleExtras:.
      sdk.handleExtras { extras in
        extras?["IABUSPrivacy_String"] = optOut ? "1YYN" : "1YNN"
      }
    }
  }

  func dispose() throws { ads.removeAll() }

  // MARK: Main-actor implementations

  @MainActor
  private func initializeOnMain(_ request: InitRequest) async throws {
    guard !request.appId.isEmpty else {
      throw PigeonError(code: "invalidConfig", message: "The Start.io App ID is empty", details: nil)
    }
    guard let sdk = STAStartAppSDK.sharedInstance() else {
      throw PigeonError(code: "internal", message: "Start.io SDK unavailable", details: nil)
    }
    sdk.testAdsEnabled = request.testMode
    if initialized { return }
    // ⚠ Swift spelling inferred from initializeWithAppID:completion:.
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      sdk.initialize(withAppID: request.appId) { _ in continuation.resume() }
    }
    initialized = true
  }

  @MainActor
  private func loadOnMain(format: AdFormatMessage, adUnitId: String) async throws -> String {
    if format == .banner {
      throw PigeonError(code: "unsupportedFormat", message: "Banners load through the platform view", details: nil)
    }
    guard let ad = STAStartAppAd() else {
      throw PigeonError(code: "internal", message: "Could not create a Start.io ad", details: nil)
    }
    counter += 1
    let holder = StartappAdHolder(id: "startapp-\(counter)", format: format, ad: ad, plugin: self)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      holder.loadContinuation = continuation
      if format == .rewarded {
        ad.loadRewardedVideoAd(withDelegate: holder)
      } else {
        // The per-format ad tag is Android-only for now (⚠ iOS preferences API).
        ad.load(withDelegate: holder)
      }
    }
    ads[holder.id] = holder
    emit(AdEventMessage(kind: .loaded, adId: holder.id, format: format))
    return holder.id
  }

  @MainActor
  private func showOnMain(adId: String) async throws {
    guard let holder = ads[adId], holder.ad.isReady() else {
      throw PigeonError(code: "notReady", message: "Start.io ad \(adId) is not ready", details: nil)
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      holder.showContinuation = continuation
      holder.ad.show()
    }
  }
}

/// One loaded Start.io interstitial / rewarded ad and its delegate.
final class StartappAdHolder: NSObject, STADelegateProtocol {
  let id: String
  let format: AdFormatMessage
  let ad: STAStartAppAd
  var loadContinuation: CheckedContinuation<Void, Error>?
  var showContinuation: CheckedContinuation<Void, Error>?
  private weak var plugin: UnifiedAdsStartappPlugin?

  init(id: String, format: AdFormatMessage, ad: STAStartAppAd, plugin: UnifiedAdsStartappPlugin) {
    self.id = id
    self.format = format
    self.ad = ad
    self.plugin = plugin
  }

  private func send(_ kind: AdEventKind) {
    plugin?.emit(AdEventMessage(kind: kind, adId: id, format: format))
  }

  @objc(didLoadAd:)
  func didLoad(_ ad: STAAbstractAd) {
    loadContinuation?.resume()
    loadContinuation = nil
  }

  @objc(failedLoadAd:withError:)
  func failedLoad(_ ad: STAAbstractAd, withError error: Error) {
    loadContinuation?.resume(
      throwing: PigeonError(code: "noFill", message: error.localizedDescription, details: String((error as NSError).code)))
    loadContinuation = nil
  }

  @objc(didShowAd:)
  func didShow(_ ad: STAAbstractAd) {
    send(.shown)
    showContinuation?.resume()
    showContinuation = nil
  }

  @objc(didSendImpression:)
  func didSendImpression(_ ad: STAAbstractAd) { send(.impression) }

  @objc(failedShowAd:withError:)
  func failedShow(_ ad: STAAbstractAd, withError error: Error) {
    plugin?.emit(
      AdEventMessage(
        kind: .failedToShow, adId: id, format: format, errorCode: "showFailed",
        errorMessage: error.localizedDescription, nativeCode: String((error as NSError).code)))
    showContinuation?.resume(
      throwing: PigeonError(code: "showFailed", message: error.localizedDescription, details: nil))
    showContinuation = nil
    plugin?.remove(id)
  }

  @objc(didClickAd:)
  func didClick(_ ad: STAAbstractAd) { send(.clicked) }

  @objc(didCloseAd:)
  func didClose(_ ad: STAAbstractAd) {
    send(.closed)
    plugin?.remove(id)
  }

  /// Start.io reports no amount/type; Dart fills in the configured default.
  @objc(didCompleteVideo:)
  func didCompleteVideo(_ ad: STAAbstractAd) { send(.earnedReward) }
}
