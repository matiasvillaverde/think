// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Factories",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "Factories",
            targets: ["Factories"])
    ],
    dependencies: [
        .package(path: "../Database"),
        .package(path: "../Rag"),
        .package(path: "../Abstractions"),
        .package(path: "../ModelDownloader"),
        .package(path: "../AudioGenerator"),
        .package(path: "../ContextBuilder"),
        .package(path: "../Tools"),
        .package(path: "../ViewModels"),
        .package(path: "../UIComponents"),
        .package(path: "../ImageGenerator"),
        .package(path: "../AgentOrchestrator"),
        .package(path: "../MLXSession"),
        .package(path: "../LLamaCPP"),
        .package(path: "../RemoteSession")
    ],
    targets: [
        .target(
            name: "Factories",
            dependencies: [
                "Rag",
                "Database",
                "Abstractions",
                "ModelDownloader",
                "AudioGenerator",
                "ContextBuilder",
                "Tools",
                "ViewModels",
                "UIComponents",
                "ImageGenerator",
                "AgentOrchestrator",
                "MLXSession",
                "LLamaCPP",
                "RemoteSession"
            ],
),
        .testTarget(
            name: "FactoriesTests",
            dependencies: [
                "Factories",
                .product(name: "AbstractionsTestUtilities", package: "Abstractions")
            ]
        )
    ]
)
