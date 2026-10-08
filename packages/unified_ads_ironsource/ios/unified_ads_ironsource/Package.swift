// swift-tools-version: 5.9
// LevelPlay adapter for unified_ads. The LevelPlay package is declared ONLY
// here, so apps that do not depend on unified_ads_ironsource never resolve it.
// Note: LevelPlay via SPM needs `-ObjC` in the app's Other Linker Flags (SPM
// cannot carry it); CocoaPods sets it automatically.

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
      ]
    )
  ]
)
