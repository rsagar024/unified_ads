// swift-tools-version: 5.9
// InMobi adapter for unified_ads. The InMobi package is declared ONLY here, so
// apps that do not depend on unified_ads_inmobi never resolve it.

import PackageDescription

let package = Package(
  name: "unified_ads_inmobi",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "unified-ads-inmobi", targets: ["unified_ads_inmobi"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(url: "https://github.com/InMobi/InMobiSDK-Swift-Package.git", exact: "11.5.0"),
  ],
  targets: [
    .target(
      name: "unified_ads_inmobi",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "InMobiSDK", package: "InMobiSDK-Swift-Package"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ],
      // InMobi's iOS guide requires WebKit, libsqlite3, libz and -ObjC (the
      // SDK uses Objective-C categories). Its Swift package (a bare binary
      // target) declares none of them. Unsafe flags are accepted here because
      // Flutter adds plugins as local path packages.
      linkerSettings: [
        .linkedFramework("WebKit"),
        .linkedLibrary("sqlite3.0"),
        .linkedLibrary("z"),
        .unsafeFlags(["-ObjC"]),
      ]
    )
  ]
)
