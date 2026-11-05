// swift-tools-version: 5.9
// Unity Ads adapter for unified_ads. The Unity Ads package is declared ONLY
// here, so apps that do not depend on unified_ads_unity never resolve it.

import PackageDescription

let package = Package(
  name: "unified_ads_unity",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "unified-ads-unity", targets: ["unified_ads_unity"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(url: "https://github.com/Unity-Technologies/Unity-Ads-Swift-Package.git", exact: "4.21.0"),
  ],
  targets: [
    .target(
      name: "unified_ads_unity",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "UnityAds", package: "Unity-Ads-Swift-Package"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
