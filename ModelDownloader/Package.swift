// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ModelDownloader",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "ModelDownloader",
            targets: ["ModelDownloader"]
        )
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")
    ],
    targets: [
        .target(
            name: "ModelDownloader",
            dependencies: [
                "Abstractions",
                "ZIPFoundation"
            ],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ],
            linkerSettings: [
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(
            name: "ModelDownloaderTests",
            dependencies: ["ModelDownloader"]
        )
    ]
)
