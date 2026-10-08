/// Ad formats supported by the unified API.
///
/// [banner], [interstitial] and [rewarded] are the core formats.
/// [rewardedInterstitial] and [appOpen] are optional capabilities that an
/// adapter advertises through its supported formats.
enum AdFormat {
  /// A rectangular ad embedded in the layout.
  banner('banner'),

  /// A full-screen ad shown at natural transition points.
  interstitial('interstitial'),

  /// A full-screen ad that grants the user a reward.
  rewarded('rewarded'),

  /// A full-screen rewarded ad that does not require an opt-in prompt.
  rewardedInterstitial('rewardedInterstitial'),

  /// A full-screen ad shown when the app is opened or brought to foreground.
  appOpen('appOpen');

  const AdFormat(this.id);

  /// Stable identifier used in JSON configuration.
  final String id;

  /// Whether this format covers the whole screen when shown.
  bool get isFullScreen => this != banner;

  /// Whether this format can grant a reward.
  bool get isRewarded => this == rewarded || this == rewardedInterstitial;

  /// Returns the format whose [id] equals [id], or `null` if none matches.
  static AdFormat? tryParse(String id) {
    for (final format in values) {
      if (format.id == id) return format;
    }
    return null;
  }
}
