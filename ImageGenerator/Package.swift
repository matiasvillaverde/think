// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ImageGenerator",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "ImageGenerator",
            targets: ["ImageGenerator"])
    ],
    dependencies: [
        .package(path: "../Abstractions")
    ],
    targets: [
        .target(
            name: "ImageGenerator",
            dependencies: [
                "Abstractions"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .define("SWIFT_DETERMINISTIC_HASHING", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "ImageGeneratorTests",
            dependencies: [
                "ImageGenerator",
                .product(
                    name: "AbstractionsTestUtilities",
                    package: "Abstractions"
                )
            ],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
