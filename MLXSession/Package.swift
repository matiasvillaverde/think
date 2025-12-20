// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MLXSession",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "MLXSession",
            targets: ["MLXSession"]),
        .library(
            name: "MLXSessionTestUtilities",
            targets: ["MLXSessionTestUtilities"])
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.30.3")),
        .package(
            url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "0.1.22")
        ),
    ],
    targets: [
        .target(
            name: "MLXSession",
            dependencies: [
                "Abstractions",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLinalg", package: "mlx-swift"),
                .product(name: "Transformers", package: "swift-transformers"),
            ]
        ),
        
        // Test Utilities
        .target(
            name: "MLXSessionTestUtilities",
            dependencies: [
                "MLXSession",
                "Abstractions",
                .product(name: "AbstractionsTestUtilities", package: "Abstractions")
            ],
            path: "Tests/MLXSessionTestUtilities/Sources"
        ),
        
        // Original test target (kept for backwards compatibility)
        .testTarget(
            name: "MLXSessionTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities",
                .product(name: "AbstractionsTestUtilities", package: "Abstractions")
            ],
            resources: [
                .copy("Resources")
            ]
        ),
        
        // Architecture-specific test targets
        .testTarget(
            name: "MLXLlamaTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXMistralTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXPhiTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXPhi3Tests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXPhiMoETests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXGemmaTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXGemma2Tests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXQwenTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXStarcoderTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXCohereTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXOpenELMTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXInternLMTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXDeepseekTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXGraniteTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXBitnetTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXSmolLMTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MLXErnieTests",
            dependencies: [
                "MLXSession",
                "MLXSessionTestUtilities"
            ],
            resources: [.copy("Resources")]
        ),
    ]
)
