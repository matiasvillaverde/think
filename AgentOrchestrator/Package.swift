// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AgentOrchestrator",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "AgentOrchestrator",
            targets: ["AgentOrchestrator"]
        )
    ],
    dependencies: [
        // Internal dependencies
        .package(path: "../Abstractions"),
        .package(path: "../Database"),
        .package(path: "../ContextBuilder"),
        .package(path: "../Tools"),
        .package(path: "../ImageGenerator"),
        .package(path: "../LLamaCPP"),
        .package(path: "../MLXSession"),
        .package(path: "../ModelDownloader")
    ],
    targets: [
        .target(
            name: "AgentOrchestrator",
            dependencies: [
                "Abstractions",
                "Database",
                "ContextBuilder",
                "Tools",
                "ImageGenerator",
                "LLamaCPP",
                "MLXSession",
                "ModelDownloader"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AgentOrchestratorTests",
            dependencies: [
                "AgentOrchestrator",
                .product(name: "AbstractionsTestUtilities", package: "Abstractions"),
                "ContextBuilder",
                "Tools"
            ]
        )
    ]
)
