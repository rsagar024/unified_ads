import 'ad_error.dart';

/// The outcome of an ad operation: either [AdSuccess] or [AdFailure].
///
/// unified_ads never throws for expected failures; operations return an
/// [AdResult] instead.
sealed class AdResult<T> {
  const AdResult();

  /// Whether the operation succeeded.
  bool get isSuccess => this is AdSuccess<T>;

  /// The value on success, otherwise `null`.
  T? get valueOrNull => switch (this) {
    AdSuccess<T>(:final value) => value,
    AdFailure<T>() => null,
  };

  /// The error on failure, otherwise `null`.
  AdError? get errorOrNull => switch (this) {
    AdSuccess<T>() => null,
    AdFailure<T>(:final error) => error,
  };
}

/// A successful [AdResult] carrying [value].
final class AdSuccess<T> extends AdResult<T> {
  /// Creates a successful result.
  const AdSuccess(this.value);

  /// The produced value.
  final T value;

  @override
  String toString() => 'AdSuccess($value)';
}

/// A failed [AdResult] carrying [error].
final class AdFailure<T> extends AdResult<T> {
  /// Creates a failed result.
  const AdFailure(this.error);

  /// What went wrong.
  final AdError error;

  @override
  String toString() => 'AdFailure($error)';
}
