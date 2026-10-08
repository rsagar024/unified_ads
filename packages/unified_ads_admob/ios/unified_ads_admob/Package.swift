// swift-tools-version: 5.9
// AdMob adapter for unified_ads. The Google packages are declared ONLY here, so
// apps that do not depend on unified_ads_admob never resolve them.

import PackageDescription

let package = Package(
  name: "unified_ads_admob",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "unified-ads-admob", targets: ["unified_ads_admob"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(
      url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
      exact: "13.11.0"),
    .package(
      url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
      exact: "3.1.0"),
  ],
  targets: [
    .target(
      name: "unified_ads_admob",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(
          name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
        .product(
          name: "GoogleUserMessagingPlatform",
          package: "swift-package-manager-google-user-messaging-platform"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
