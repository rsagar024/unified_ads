import Flutter
import Network
import UIKit
import UnityAds

let unityBannerViewType = "dev.arovyx.plugin.unifiedads/unity/banner"

/// Unity Ads adapter plugin, built only on the 4.19+ instance APIs
/// (`UADSInterstitialAd`, `UADSRewardedAd`, `UADSBannerAd`).
///
/// ⚠ Unity's docs disagree on several Swift names (for example
/// `showDidFail` vs `showDidFailed`); these follow the guides and the
/// AppLovin Unity adapter and must be verified by the CI build.
public final class UnifiedAdsUnityPlugin: NSObject, FlutterPlugin, UnityHostApi {
  private let events: UnityEventsApi
  private var ads: [String: UnityAdHolder] = [:]
  private var counter = 0
  private var initialized = false
  private var initRunning = false
  private var initWaiters: [(PigeonError?) -> Void] = []
  /// Tracks connectivity: Unity cannot initialize offline (see initializeOnMain).
  private let pathMonitor = NWPathMonitor()
  private var pendingEvents: [AdEventMessage] = []
  private var draining = false

  init(messenger: FlutterBinaryMessenger) {
    events = UnityEventsApi(binaryMessenger: messenger)
    super.init()
    pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = UnifiedAdsUnityPlugin(messenger: registrar.messenger())
    UnityHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.register(UnityBannerFactory(plugin: instance), withId: unityBannerViewType)
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    UnityHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
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

  // MARK: UnityHostApi

  func initialize(request: InitRequest) async throws { try await initializeOnMain(request) }

  func load(format: AdFormatMessage, adUnitId: String) async throws -> String {
    try await loadOnMain(format: format, adUnitId: adUnitId)
  }

  func show(adId: String) async throws { try await showOnMain(adId: adId) }

  func destroy(adId: String) throws { remove(adId) }

  func applyConsent(consent: ConsentMessage) throws {
    // Unity requires these before (or during) initialization.
    if let given = consent.consentGiven { UnityAds.setUserConsent(given) }
    if let optOut = consent.ccpaOptOut { UnityAds.setUserOptOut(optOut) }
    UnityAds.setNonBehavioral(consent.coppa)
  }

  func dispose() throws { ads.removeAll() }

  // MARK: Main-actor implementations

  @MainActor
  private func initializeOnMain(_ request: InitRequest) async throws {
    guard !request.appId.isEmpty else {
      throw PigeonError(code: "invalidConfig", message: "The Unity Game ID is empty", details: nil)
    }
    if initialized { return }
    // Unity must download its game configuration before it reports completion;
    // offline, the SDK waits for connectivity and never calls back. Start it
    // anyway (it finishes by itself once online, so a later init call succeeds
    // at once) but fail fast instead of timing out.
    startInitialization(request)
    if pathMonitor.currentPath.status == .unsatisfied {
      throw PigeonError(
        code: "networkError",
        message: "No internet connection: Unity Ads must download its configuration to "
          + "initialize. It completes automatically once the device is online; "
          + "call UnifiedAds.init again after reconnecting.",
        details: nil)
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      initWaiters.append { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /// Starts one native initialization; concurrent init calls share it.
  @MainActor
  private func startInitialization(_ request: InitRequest) {
    if initRunning { return }
    initRunning = true
    let configuration = UADSInitializationConfigurationBuilder(gameId: request.appId)
      .with(testMode: request.testMode)
      .build()
    UnityAds.initialize(configuration) { error in
      let failure = error.map {
        PigeonError(code: "initializationFailed", message: $0.message, details: String($0.code))
      }
      DispatchQueue.main.async {
        self.initRunning = false
        if failure == nil { self.initialized = true }
        let waiters = self.initWaiters
        self.initWaiters.removeAll()
        waiters.forEach { $0(failure) }
      }
    }
  }

  @MainActor
  private func loadOnMain(format: AdFormatMessage, adUnitId: String) async throws -> String {
    if format == .banner {
      throw PigeonError(code: "unsupportedFormat", message: "Banners load through the platform view", details: nil)
    }
    counter += 1
    let holder = UnityAdHolder(id: "unity-\(counter)", format: format, plugin: self)
    let configuration = UADSLoadConfigurationBuilder(placementId: adUnitId).build()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      if format == .rewarded {
        UADSRewardedAd.load(configuration) { ad, error in
          holder.rewarded = ad
          Self.finishLoad(continuation, loaded: ad != nil, error: error)
        }
      } else {
        UADSInterstitialAd.load(configuration) { ad, error in
          holder.interstitial = ad
          Self.finishLoad(continuation, loaded: ad != nil, error: error)
        }
      }
    }
    ads[holder.id] = holder
    emit(AdEventMessage(kind: .loaded, adId: holder.id, format: format))
    return holder.id
  }

  private static func finishLoad(
    _ continuation: CheckedContinuation<Void, Error>, loaded: Bool, error: UnityAdsError?
  ) {
    if loaded {
      continuation.resume()
    } else {
      let code = error?.code ?? 52100
      continuation.resume(
        throwing: PigeonError(
          code: UnityErrors.loadCode(code), message: error?.message ?? "Unity Ads load failed",
          details: String(code)))
    }
  }

  @MainActor
  private func showOnMain(adId: String) async throws {
    guard let holder = ads[adId] else {
      throw PigeonError(code: "notReady", message: "No loaded Unity ad with id \(adId)", details: nil)
    }
    guard let viewController = Self.topViewController() else {
      throw PigeonError(code: "noActivity", message: "No view controller to present the ad", details: nil)
    }
    let configuration = UADSShowConfigurationBuilder().with(viewController: viewController).build()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      holder.showContinuation = continuation
      holder.interstitial?.show(configuration, delegate: holder)
      holder.rewarded?.show(configuration, delegate: holder)
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

/// `UnityAdsError.code` → `AdErrorCode` name.
enum UnityErrors {
  static func loadCode(_ code: Int) -> String {
    switch code {
    case 52100: return "noFill"
    case 52101: return "notInitialized"
    case 52102, 52104: return "invalidConfig"
    case 2: return "timeout"
    case 52005, 52105: return "networkError"
    default: return "internal"
    }
  }

  static func showCode(_ code: Int) -> String {
    switch code {
    case 52200: return "notReady"
    case 52201: return "alreadyShowing"
    default: return "showFailed"
    }
  }
}

/// One loaded Unity interstitial / rewarded ad and its show delegate.
final class UnityAdHolder: NSObject, UADSInterstitialShowDelegate, UADSRewardedShowDelegate {
  let id: String
  let format: AdFormatMessage
  var interstitial: UADSInterstitialAd?
  var rewarded: UADSRewardedAd?
  var showContinuation: CheckedContinuation<Void, Error>?
  private weak var plugin: UnifiedAdsUnityPlugin?

  init(id: String, format: AdFormatMessage, plugin: UnifiedAdsUnityPlugin) {
    self.id = id
    self.format = format
    self.plugin = plugin
  }

  private func send(_ kind: AdEventKind) {
    plugin?.emit(AdEventMessage(kind: kind, adId: id, format: format))
  }

  private func started() {
    send(.shown)
    send(.impression)
    showContinuation?.resume()
    showContinuation = nil
  }

  private func completed() {
    send(.closed)
    plugin?.remove(id)
  }

  private func failed(_ error: UnityAdsError) {
    let code = UnityErrors.showCode(error.code)
    plugin?.emit(
      AdEventMessage(
        kind: .failedToShow, adId: id, format: format, errorCode: code, errorMessage: error.message,
        nativeCode: String(error.code)))
    showContinuation?.resume(throwing: PigeonError(code: code, message: error.message, details: String(error.code)))
    showContinuation = nil
    plugin?.remove(id)
  }

  // UADSInterstitialShowDelegate
  func showDidStart(_ unityAd: UADSInterstitialAd) { started() }
  func showDidClick(_ unityAd: UADSInterstitialAd) { send(.clicked) }
  func showDidComplete(_ unityAd: UADSInterstitialAd, with state: UADSShowFinishState) { completed() }
  func showDidFail(_ unityAd: UADSInterstitialAd, error: UnityAdsError) { failed(error) }

  // UADSRewardedShowDelegate
  func showDidStart(_ unityAd: UADSRewardedAd) { started() }
  func showDidClick(_ unityAd: UADSRewardedAd) { send(.clicked) }
  /// Unity reports no amount/type; Dart fills in the configured default.
  func showDidReceiveReward(_ unityAd: UADSRewardedAd) { send(.earnedReward) }
  func showDidComplete(_ unityAd: UADSRewardedAd, with state: UADSShowFinishState) { completed() }
  func showDidFail(_ unityAd: UADSRewardedAd, error: UnityAdsError) { failed(error) }
}
