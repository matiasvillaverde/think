// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DataAssets",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "DataAssets",
            targets: ["DataAssets"])
    ],
    targets: [
        .target(
            name: "DataAssets",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]),
        .testTarget(
            name: "DataAssetsTests",
            dependencies: ["DataAssets"]
        )
    ]
)