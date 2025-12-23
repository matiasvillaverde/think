// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Abstractions",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "Abstractions",
            targets: ["Abstractions"]),
        .library(
            name: "AbstractionsTestUtilities",
            targets: ["AbstractionsTestUtilities"])
    ],
    dependencies: [
        .package(path: "../DataAssets")
    ],
    targets: [
        .target(
            name: "Abstractions",
            dependencies: ["DataAssets"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ],
),
        .target(
            name: "AbstractionsTestUtilities",
            dependencies: ["Abstractions"]),
        .testTarget(
            name: "AbstractionsTests",
            dependencies: [
                "Abstractions",
                "AbstractionsTestUtilities"
            ]
        )
    ]
)
