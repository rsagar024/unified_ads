// swift-tools-version: 5.9
// AppLovin MAX adapter for unified_ads. The AppLovin package is declared ONLY
// here, so apps that do not depend on unified_ads_applovin never resolve it.

import PackageDescription

let package = Package(
  name: "unified_ads_applovin",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "unified-ads-applovin", targets: ["unified_ads_applovin"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", exact: "13.6.4"),
  ],
  targets: [
    .target(
      name: "unified_ads_applovin",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
