// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Database",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "Database",
            targets: ["Database"])
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(path: "../DataAssets"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.1")
    ],
    targets: [
        .target(
            name: "Database",
            dependencies: [
                "Abstractions",
                "DataAssets",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            resources: [
                .process("Resources/Localizable.xcstrings"),
                .process("Resources/Media.xcassets")
            ],
        ),
        .testTarget(
            name: "DatabaseTests",
            dependencies: [
                "Database",
                .product(
                    name: "AbstractionsTestUtilities",
                    package: "Abstractions"
                )
            ]
        )
    ]
)
