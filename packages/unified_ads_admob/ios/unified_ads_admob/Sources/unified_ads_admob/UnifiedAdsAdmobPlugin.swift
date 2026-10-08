import Flutter
import GoogleMobileAds
import UIKit

/// AdMob adapter plugin: Pigeon host API, platform-view factory for banners and
/// view-controller lookup for full-screen ads and the UMP consent form.
///
/// Pigeon invokes the async host methods from a `@MainActor` task; each one
/// delegates to a `@MainActor` implementation so every SDK call runs on the
/// main thread.
public final class UnifiedAdsAdmobPlugin: NSObject, FlutterPlugin, AdmobHostApi {
  private let events: AdmobEventsApi
  private var ads: [String: FullScreenAdHolder] = [:]
  private var counter = 0
  private var initialized = false
  private var testDeviceIds: [String] = []
  private var coppa = false
  private var pendingEvents: [AdEventMessage] = []
  private var draining = false

  init(messenger: FlutterBinaryMessenger) {
    events = AdmobEventsApi(binaryMessenger: messenger)
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = UnifiedAdsAdmobPlugin(messenger: registrar.messenger())
    AdmobHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.register(AdmobBannerFactory(plugin: instance), withId: bannerViewType)
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    AdmobHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    clearAds()
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

  func removeAd(_ id: String) {
    ads.removeValue(forKey: id)?.clear()
  }

  // MARK: AdmobHostApi

  func initialize(request: InitRequest) async throws -> InitInfo {
    try await initializeOnMain(request)
  }

  func load(format: AdFormatMessage, adUnitId: String) async throws -> String {
    try await loadOnMain(format: format, adUnitId: adUnitId)
  }

  func show(adId: String) async throws {
    try await showOnMain(adId: adId)
  }

  func destroy(adId: String) throws {
    removeAd(adId)
  }

  func applyConsent(consent: ConsentMessage) throws {
    coppa = consent.coppa
    if initialized { applyRequestConfiguration() }
    // Restricted data processing (US state privacy laws): the documented
    // mechanism is `gad_rdp` in the standard user defaults.
    switch consent.ccpaOptOut {
    case .some(true): UserDefaults.standard.set(true, forKey: "gad_rdp")
    case .some(false): UserDefaults.standard.removeObject(forKey: "gad_rdp")
    case .none: break
    }
    // Opt-in Meta bidding: privacy reaches Audience Network before
    // MobileAds starts the adapter (consent is applied before init).
    if MetaBidding.detect() != nil {
      MetaBidding.applyPrivacy(ccpaOptOut: consent.ccpaOptOut, coppa: consent.coppa)
    }
  }

  func dispose() throws {
    clearAds()
  }

  func gatherConsent(request: GatherRequest) async throws -> ConsentInfo {
    try await gatherOnMain(request)
  }

  func showPrivacyOptions() async throws {
    try await showPrivacyOptionsOnMain()
  }

  func consentInfo() throws -> ConsentInfo {
    Consent.snapshot()
  }

  // MARK: Main-actor implementations

  @MainActor
  private func initializeOnMain(_ request: InitRequest) async throws -> InitInfo {
    let appId = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
    guard let appId, !appId.isEmpty else {
      throw Errors.of(
        "invalidConfig",
        "Add GADApplicationIdentifier to Info.plist (see docs/setup/admob.md)")
    }
    if let configured = request.appId, !configured.isEmpty, configured != appId {
      NSLog("[unified_ads_admob] NetworkConfig.appId differs from Info.plist; Info.plist is used.")
    }
    testDeviceIds = request.testDeviceIds
    applyRequestConfiguration()
    let info = InitInfo(metaBiddingAdapter: MetaBidding.detect())
    if initialized { return info }
    _ = await MobileAds.shared.start()
    initialized = true
    return info
  }

  @MainActor
  private func loadOnMain(format: AdFormatMessage, adUnitId: String) async throws -> String {
    let holder: FullScreenAdHolder
    do {
      switch format {
      case .interstitial:
        let ad = try await InterstitialAd.load(with: adUnitId, request: Request())
        holder = register(format)
        holder.interstitial = ad
        ad.fullScreenContentDelegate = holder
      case .rewarded:
        let ad = try await RewardedAd.load(with: adUnitId, request: Request())
        holder = register(format)
        holder.rewarded = ad
        ad.fullScreenContentDelegate = holder
      case .rewardedInterstitial:
        let ad = try await RewardedInterstitialAd.load(with: adUnitId, request: Request())
        holder = register(format)
        holder.rewardedInterstitial = ad
        ad.fullScreenContentDelegate = holder
      case .appOpen:
        let ad = try await AppOpenAd.load(with: adUnitId, request: Request())
        holder = register(format)
        holder.appOpen = ad
        ad.fullScreenContentDelegate = holder
      case .banner:
        throw Errors.of("unsupportedFormat", "Banners are loaded through the platform view")
      }
    } catch let error as PigeonError {
      throw error
    } catch {
      throw Errors.load(error)
    }
    emit(AdEventMessage(kind: .loaded, adId: holder.id, format: format))
    return holder.id
  }

  @MainActor
  private func showOnMain(adId: String) async throws {
    guard let holder = ads[adId] else {
      throw Errors.of("notReady", "No loaded AdMob ad with id \(adId)")
    }
    guard let viewController = Self.topViewController() else {
      throw Errors.of("noActivity", "No view controller to present the ad from")
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      holder.showContinuation = continuation
      if let ad = holder.interstitial {
        ad.present(from: viewController)
      } else if let ad = holder.rewarded {
        ad.present(from: viewController) { [weak self, weak holder] in
          guard let self, let holder, let reward = holder.rewarded?.adReward else { return }
          self.emit(
            AdEventMessage(
              kind: .earnedReward, adId: holder.id, format: holder.format,
              rewardAmount: reward.amount.doubleValue, rewardType: reward.type))
        }
      } else if let ad = holder.rewardedInterstitial {
        ad.present(from: viewController) { [weak self, weak holder] in
          guard let self, let holder, let reward = holder.rewardedInterstitial?.adReward else {
            return
          }
          self.emit(
            AdEventMessage(
              kind: .earnedReward, adId: holder.id, format: holder.format,
              rewardAmount: reward.amount.doubleValue, rewardType: reward.type))
        }
      } else if let ad = holder.appOpen {
        ad.present(from: viewController)
      } else {
        holder.showContinuation = nil
        continuation.resume(throwing: Errors.of("notReady", "Ad \(adId) was released"))
      }
    }
  }

  @MainActor
  private func gatherOnMain(_ request: GatherRequest) async throws -> ConsentInfo {
    guard let viewController = Self.topViewController() else {
      throw Errors.of("noActivity", "No view controller for the consent form")
    }
    return try await Consent.gather(request: request, from: viewController)
  }

  @MainActor
  private func showPrivacyOptionsOnMain() async throws {
    guard let viewController = Self.topViewController() else {
      throw Errors.of("noActivity", "No view controller for the privacy form")
    }
    try await Consent.showPrivacyOptions(from: viewController)
  }

  // MARK: Helpers

  private func register(_ format: AdFormatMessage) -> FullScreenAdHolder {
    counter += 1
    let holder = FullScreenAdHolder(id: "admob-\(counter)", format: format, plugin: self)
    ads[holder.id] = holder
    return holder
  }

  private func clearAds() {
    ads.values.forEach { $0.clear() }
    ads.removeAll()
  }

  private func applyRequestConfiguration() {
    let configuration = MobileAds.shared.requestConfiguration
    configuration.testDeviceIdentifiers = testDeviceIds
    configuration.ageRestrictedTreatment = coppa ? .child : .unspecified
  }

  /// The top-most view controller of the key window.
  static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
