// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ViewModels",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "ViewModels",
            targets: ["ViewModels"])
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(path: "../DataAssets"),
        .package(path: "../Database"),
        .package(path: "../RemoteSession"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.1")
    ],
    targets: [
        .target(
            name: "ViewModels",
            dependencies: [
                "Abstractions",
                "DataAssets",
                "Database",
                "RemoteSession",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
        .testTarget(
            name: "ViewModelsTests",
            dependencies: [
                "ViewModels",
                .product(
                    name: "AbstractionsTestUtilities",
                    package: "Abstractions"
                )
            ]
        )
    ]
)
