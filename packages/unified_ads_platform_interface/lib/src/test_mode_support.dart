/// How far an adapter can honour the test-mode flag.
enum TestModeSupport {
  /// The SDK has a code-level test-ads switch (Unity Ads, Start.io).
  flag,

  /// Test ads are served to registered test devices (AdMob, AppLovin MAX).
  testDevices,

  /// Only a test suite / debugger is available (LevelPlay).
  testSuiteOnly,

  /// Test mode can only be enabled in the network dashboard (InMobi).
  none;

  /// Whether setting test mode in code reliably produces test ads.
  bool get canForceTestAds => this == flag || this == testDevices;
}
