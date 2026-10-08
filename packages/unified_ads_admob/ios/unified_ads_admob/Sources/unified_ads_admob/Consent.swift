import UIKit
import UserMessagingPlatform

/// Google UMP consent flow plus the IAB values UMP stores on the device.
/// UMP requires every call on the main thread.
enum Consent {
  @MainActor
  static func gather(request: GatherRequest, from viewController: UIViewController) async throws
    -> ConsentInfo
  {
    let parameters = RequestParameters()
    if request.debugGeography != nil || !request.testDeviceHashedIds.isEmpty {
      let debug = DebugSettings()
      debug.testDeviceIdentifiers = request.testDeviceHashedIds
      // DebugGeography raw values: EEA = 1, regulatedUSState = 3, other = 4.
      switch request.debugGeography {
      case .eea: debug.geography = DebugGeography(rawValue: 1) ?? debug.geography
      case .regulatedUsState: debug.geography = DebugGeography(rawValue: 3) ?? debug.geography
      case .other: debug.geography = DebugGeography(rawValue: 4) ?? debug.geography
      case nil: break
      }
      parameters.debugSettings = debug
    }

    do {
      try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
    } catch {
      throw failure(error)
    }

    do {
      if request.forceForm,
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
      {
        try await ConsentForm.presentPrivacyOptionsForm(from: viewController)
      } else {
        try await ConsentForm.loadAndPresentIfRequired(from: viewController)
      }
    } catch {
      // A form error (e.g. no message configured) is not fatal: report the state.
      NSLog("[unified_ads_admob] UMP form error: \(error.localizedDescription)")
    }
    return snapshot()
  }

  @MainActor
  static func showPrivacyOptions(from viewController: UIViewController) async throws {
    do {
      try await ConsentForm.presentPrivacyOptionsForm(from: viewController)
    } catch {
      throw failure(error)
    }
  }

  static func snapshot() -> ConsentInfo {
    let defaults = UserDefaults.standard
    let gdprApplies = (defaults.object(forKey: "IABTCF_gdprApplies") as? NSNumber)?.int64Value
    return ConsentInfo(
      canRequestAds: ConsentInformation.shared.canRequestAds,
      privacyOptionsRequired: ConsentInformation.shared.privacyOptionsRequirementStatus
        == .required,
      gdprApplies: gdprApplies,
      tcString: defaults.string(forKey: "IABTCF_TCString"),
      purposeConsents: defaults.string(forKey: "IABTCF_PurposeConsents"),
      gppString: defaults.string(forKey: "IABGPP_HDR_GppString"))
  }

  private static func failure(_ error: Error) -> PigeonError {
    let ns = error as NSError
    return PigeonError(code: "internal", message: ns.localizedDescription, details: String(ns.code))
  }
}
