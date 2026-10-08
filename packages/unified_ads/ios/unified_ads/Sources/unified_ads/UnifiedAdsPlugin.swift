import AppTrackingTransparency
import Flutter
import UIKit

/// Core unified_ads plugin.
///
/// Provides the App Tracking Transparency helper behind
/// `UnifiedAds.requestTrackingAuthorization()` on channel
/// `dev.arovyx.plugin.unifiedads/tracking`. Network SDKs live only in adapter
/// packages.
public class UnifiedAdsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.arovyx.plugin.unifiedads/tracking", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(UnifiedAdsPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getTrackingStatus":
      result(Self.currentStatus())
    case "requestTracking":
      guard #available(iOS 14, *) else {
        result("notApplicable")
        return
      }
      // Requires NSUserTrackingUsageDescription in Info.plist. The prompt only
      // appears while the app is active.
      ATTrackingManager.requestTrackingAuthorization { status in
        DispatchQueue.main.async { result(Self.name(of: status)) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func currentStatus() -> String {
    guard #available(iOS 14, *) else { return "notApplicable" }
    return name(of: ATTrackingManager.trackingAuthorizationStatus)
  }

  @available(iOS 14, *)
  private static func name(of status: ATTrackingManager.AuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorized: return "authorized"
    @unknown default: return "unavailable"
    }
  }
}
