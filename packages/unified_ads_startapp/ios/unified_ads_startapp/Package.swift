// swift-tools-version: 5.9
// Start.io (StartApp) adapter for unified_ads. The Start.io package is
// declared ONLY here, so apps that do not depend on unified_ads_startapp never
// resolve it.

import PackageDescription

let package = Package(
  name: "unified_ads_startapp",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "unified-ads-startapp", targets: ["unified_ads_startapp"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(url: "https://github.com/StartApp-SDK/StartAppSDK-SwiftPackage.git", exact: "4.15.0"),
  ],
  targets: [
    .target(
      name: "unified_ads_startapp",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "StartApp", package: "StartAppSDK-SwiftPackage"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ],
      // The StartAppSDK pod declares these system frameworks; its Swift
      // package (a bare binary target) doesn't, so link them here.
      linkerSettings: [
        .linkedFramework("AdSupport"),
        .linkedFramework("AppTrackingTransparency"),
        .linkedFramework("AVFoundation"),
        .linkedFramework("CoreAudio"),
        .linkedFramework("CoreFoundation"),
        .linkedFramework("CoreGraphics"),
        .linkedFramework("CoreMedia"),
        .linkedFramework("CoreTelephony"),
        .linkedFramework("Foundation"),
        .linkedFramework("JavaScriptCore"),
        .linkedFramework("NetworkExtension"),
        .linkedFramework("QuartzCore"),
        .linkedFramework("StoreKit"),
        .linkedFramework("SystemConfiguration"),
        .linkedFramework("UIKit"),
        .linkedFramework("WebKit"),
        .linkedLibrary("z"),
      ]
    )
  ]
)
