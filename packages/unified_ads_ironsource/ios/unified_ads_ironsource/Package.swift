// swift-tools-version: 5.9
// LevelPlay adapter for unified_ads. The LevelPlay package is declared ONLY
// here, so apps that do not depend on unified_ads_ironsource never resolve it.
// LevelPlay needs `-ObjC` (Objective-C categories). The target below passes
// it as an unsafe flag, which SwiftPM accepts because Flutter adds plugins as
// local path packages.

import PackageDescription

let package = Package(
  name: "unified_ads_ironsource",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "unified-ads-ironsource", targets: ["unified_ads_ironsource"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(url: "https://github.com/ironsource-mobile/LevelPlay-Swift-Package.git", exact: "9.6.1"),
  ],
  targets: [
    .target(
      name: "unified_ads_ironsource",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "UnityMediationSDK", package: "LevelPlay-Swift-Package"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ],
      linkerSettings: [
        .unsafeFlags(["-ObjC"])
      ]
    )
  ]
)
