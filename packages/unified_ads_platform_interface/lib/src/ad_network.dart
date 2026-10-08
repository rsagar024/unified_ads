/// The ad networks unified_ads knows about.
///
/// A network is only usable at runtime when its adapter package (for example
/// `unified_ads_admob`) is a dependency of the app and has registered itself
/// with the `AdapterRegistry`.
enum AdNetwork {
  /// Google AdMob (Google Mobile Ads SDK).
  admob('admob', 'AdMob'),

  /// Unity Ads (standalone SDK).
  unity('unity', 'Unity Ads'),

  /// AppLovin MAX.
  applovin('applovin', 'AppLovin MAX'),

  /// ironSource / Unity LevelPlay.
  ironsource('ironsource', 'ironSource LevelPlay'),

  /// Facebook Audience Network, branded Meta Audience Network since 2022
  /// (documented stub; see SDK_STATUS.md).
  facebook('facebook', 'Facebook Audience Network'),

  /// Start.io (formerly StartApp).
  startapp('startapp', 'Start.io'),

  /// InMobi.
  inmobi('inmobi', 'InMobi');

  const AdNetwork(this.id, this.displayName);

  /// Stable identifier used in JSON configuration and channel names.
  final String id;

  /// Human-readable name for logs and UIs.
  final String displayName;

  /// Returns the network whose [id] equals [id], or `null` if none matches.
  static AdNetwork? tryParse(String id) {
    for (final network in values) {
      if (network.id == id) return network;
    }
    return null;
  }
}
