import Foundation

/// Maps Google Mobile Ads errors to `AdErrorCode` names understood by Dart.
///
/// Codes follow `RequestError.Code` (Obj-C `GADErrorCode`) from the official
/// reference: 0 invalidRequest, 1 noFill, 2 networkError, 3 serverError,
/// 5 timeout, 11 internalError, 12 invalidArgument, 19 adAlreadyUsed,
/// 20 applicationIdentifierMissing, 21 receivedInvalidAdString.
enum Errors {
  static func loadCode(_ code: Int) -> String {
    switch code {
    case 1: return "noFill"
    case 2, 3: return "networkError"
    case 5: return "timeout"
    case 0, 12, 20, 21: return "invalidConfig"
    default: return "internal"
    }
  }

  static func showCode(_ code: Int) -> String {
    switch code {
    // GADPresentationErrorCode 15 adNotReady / 18 adAlreadyUsed; GADErrorCode 19 adAlreadyUsed.
    case 15, 18, 19: return "notReady"
    default: return "showFailed"
    }
  }

  static func load(_ error: Error) -> PigeonError {
    let ns = error as NSError
    return PigeonError(
      code: loadCode(ns.code), message: ns.localizedDescription, details: String(ns.code))
  }

  static func show(_ error: Error) -> PigeonError {
    let ns = error as NSError
    return PigeonError(
      code: showCode(ns.code), message: ns.localizedDescription, details: String(ns.code))
  }

  static func of(_ code: String, _ message: String) -> PigeonError {
    PigeonError(code: code, message: message, details: nil)
  }
}
