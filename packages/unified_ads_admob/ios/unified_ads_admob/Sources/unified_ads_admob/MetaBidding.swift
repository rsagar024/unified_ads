import Foundation
import ObjectiveC

/// Optional Meta (Facebook) Audience Network bidding through AdMob mediation.
///
/// This package declares no Meta dependency. An app opts in by adding the
/// vendor's Meta adapter (Swift package `googleads-mobile-ios-mediation-meta`, product `MetaAdapterTarget`; see
/// doc/setup/admob.md). This type then detects the adapter and forwards
/// privacy signals to the Audience Network SDK before AdMob initializes it,
/// through the Objective-C runtime so the package builds without Meta's SDK.
enum MetaBidding {
  /// The Meta adapter class shipped by `GoogleMobileAdsMediationFacebook`.
  static let adapterClass = "GADMediationAdapterFacebook"

  private typealias OptionsFn = @convention(c) (AnyClass, Selector, NSArray) -> Void
  private typealias GeoOptionsFn = @convention(c) (AnyClass, Selector, NSArray, Int, Int) -> Void
  private typealias BoolFn = @convention(c) (AnyClass, Selector, ObjCBool) -> Void
  private typealias StatusFn = @convention(c) (AnyClass, Selector) -> UInt

  /// The adapter class name when the app added the Meta adapter, otherwise nil.
  static func detect() -> String? {
    NSClassFromString(adapterClass) != nil ? adapterClass : nil
  }

  /// Applies the app's privacy choices to `FBAdSettings`: CCPA opt-out becomes
  /// Limited Data Use, COPPA becomes mixed audience, and below iOS 17 the ATT
  /// flag is set. Returns false (and does nothing) when the Audience Network
  /// SDK is absent.
  @discardableResult
  static func applyPrivacy(ccpaOptOut: Bool?, coppa: Bool) -> Bool {
    guard let settings = NSClassFromString("FBAdSettings") else { return false }
    switch ccpaOptOut {
    case .some(true):
      if let (sel, imp) = classMethod(settings, "setDataProcessingOptions:country:state:") {
        unsafeBitCast(imp, to: GeoOptionsFn.self)(settings, sel, ["LDU"] as NSArray, 0, 0)
      }
    case .some(false):
      if let (sel, imp) = classMethod(settings, "setDataProcessingOptions:") {
        unsafeBitCast(imp, to: OptionsFn.self)(settings, sel, [] as NSArray)
      }
    case .none:
      break
    }
    if let (sel, imp) = classMethod(settings, "setMixedAudience:") {
      unsafeBitCast(imp, to: BoolFn.self)(settings, sel, ObjCBool(coppa))
    }
    applyAdvertiserTracking()
    return true
  }

  /// Meta requires `setAdvertiserTrackingEnabled:` on iOS 14.5–16.x, from the
  /// ATT status, before the mediation SDK starts Audience Network; on iOS 17+
  /// (SDK 6.15+) Audience Network reads the status itself. Both classes are
  /// looked up at runtime: this package neither links Audience Network nor
  /// strong-links AppTrackingTransparency (it supports iOS 13).
  static func applyAdvertiserTracking() {
    if #available(iOS 17, *) { return }
    guard let settings = NSClassFromString("FBAdSettings"),
      let manager = NSClassFromString("ATTrackingManager"),
      let status = class_getClassMethod(manager, NSSelectorFromString("trackingAuthorizationStatus")),
      let (sel, imp) = classMethod(settings, "setAdvertiserTrackingEnabled:")
    else { return }
    let current = unsafeBitCast(method_getImplementation(status), to: StatusFn.self)(
      manager, method_getName(status))
    // ATTrackingManager.AuthorizationStatus.authorized == 3.
    unsafeBitCast(imp, to: BoolFn.self)(settings, sel, ObjCBool(current == 3))
  }

  private static func classMethod(_ cls: AnyClass, _ name: String) -> (Selector, IMP)? {
    let sel = NSSelectorFromString(name)
    guard let method = class_getClassMethod(cls, sel) else {
      NSLog("[unified_ads] FBAdSettings.\(name) not found; Meta privacy setting skipped")
      return nil
    }
    return (sel, method_getImplementation(method))
  }
}
