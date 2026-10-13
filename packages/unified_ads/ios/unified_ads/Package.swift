// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "unified_ads",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "unified-ads", targets: ["unified_ads"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "unified_ads",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // Privacy manifest: nothing collected, no required-reason API.
                .process("PrivacyInfo.xcprivacy")
            ],
            linkerSettings: [
                // ATT (iOS 14+) is weak-linked so the plugin still loads on
                // iOS 13. Unsafe flags are accepted because Flutter adds
                // plugins as local path packages.
                .unsafeFlags(["-weak_framework", "AppTrackingTransparency"])
            ]
        )
    ]
)
