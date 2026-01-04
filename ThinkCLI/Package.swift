// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThinkCLI",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "think",
            targets: ["ThinkCLI"]
        )
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(path: "../AgentOrchestrator"),
        .package(path: "../Database"),
        .package(path: "../Factories"),
        .package(path: "../LLamaCPP"),
        .package(path: "../MLXSession"),
        .package(path: "../ModelDownloader"),
        .package(path: "../RemoteSession"),
        .package(path: "../Tools"),
        .package(path: "../ViewModels"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0")
    ],
    targets: [
        .executableTarget(
            name: "ThinkCLI",
            dependencies: [
                "Abstractions",
                "AgentOrchestrator",
                "Database",
                "Factories",
                "LLamaCPP",
                "MLXSession",
                "ModelDownloader",
                "RemoteSession",
                "Tools",
                "ViewModels",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "ThinkCLITests",
            dependencies: [
                "ThinkCLI",
                .product(name: "AbstractionsTestUtilities", package: "Abstractions")
            ],
            path: "Tests/ThinkCLITests"
        )
    ]
)
