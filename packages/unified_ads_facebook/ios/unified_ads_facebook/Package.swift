// swift-tools-version: 5.9
// Facebook Audience Network adapter for unified_ads. The FBAudienceNetwork
// package is declared ONLY here, so apps that do not depend on
// unified_ads_facebook never resolve it. FBAudienceNetwork 6.22 requires iOS 15
// and recommends SPM (CocoaPods distribution is being wound down by Meta).

import PackageDescription

let package = Package(
  name: "unified_ads_facebook",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "unified-ads-facebook", targets: ["unified_ads_facebook"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(url: "https://github.com/facebook/FBAudienceNetwork.git", exact: "6.22.0"),
  ],
  targets: [
    .target(
      name: "unified_ads_facebook",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        // ⚠ Product name to be confirmed by the CI build.
        .product(name: "FBAudienceNetwork", package: "FBAudienceNetwork"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
