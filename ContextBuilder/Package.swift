// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContextBuilder",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "ContextBuilder",
            targets: ["ContextBuilder"]
        )
    ],
    dependencies: [
        .package(path: "../Abstractions")
    ],
    targets: [
        .target(
            name: "ContextBuilder",
            dependencies: ["Abstractions"],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ContextBuilderTests",
            dependencies: ["ContextBuilder"],
            resources: [
                .process("Examples-ChatML"),
                .copy("Example-Qwen"),
                .copy("Examples-Harmony"),
                .process("Examples-LLama3"),
                .process("Examples-Mixtral"),
            ]
        ),
    ]
)
