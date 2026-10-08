/// App Tracking Transparency authorization status (iOS 14+).
enum TrackingStatus {
  /// The user has not been asked yet.
  notDetermined,

  /// Tracking is restricted (for example by parental controls).
  restricted,

  /// The user denied tracking.
  denied,

  /// The user authorized tracking.
  authorized,

  /// The platform has no tracking authorization concept (Android, iOS < 14).
  notApplicable,

  /// The status could not be determined (for example the native helper is
  /// missing).
  unavailable,
}

/// Access to the platform's tracking authorization (App Tracking
/// Transparency on iOS).
abstract class TrackingAuthorization {
  /// Allows subclasses to have `const` constructors.
  const TrackingAuthorization();

  /// Current status without prompting the user.
  Future<TrackingStatus> status();

  /// Shows the system prompt if the status is
  /// [TrackingStatus.notDetermined], then returns the resulting status.
  /// Requires `NSUserTrackingUsageDescription` in Info.plist.
  Future<TrackingStatus> request();
}
