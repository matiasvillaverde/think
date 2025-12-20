// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AudioGenerator",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "AudioGenerator",
            targets: ["AudioGenerator"])
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.25.4")
    ],
    targets: [
        .target(
            name: "AudioGenerator",
            dependencies: [
                "Abstractions",
                "ESpeakNG",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXFFT", package: "mlx-swift")
            ],
            resources: [
                .process("Resources/kokoro-v1_0.safetensors"),
                .process("Resources/Media.xcassets"),
                .process("Resources/af_heart.json"),
                .process("Resources/zf_xiaoni.json"),
                .process("Resources/bm_george.json"),
                .process("Resources/config.json"),
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .binaryTarget(
            name: "ESpeakNG",
            path: "../Frameworks/ESpeakNG.xcframework"
        ),
        .testTarget(
            name: "AudioGeneratorTests",
            dependencies: [
                "AudioGenerator",
                .product(name: "AbstractionsTestUtilities", package: "Abstractions")
            ]
        )
    ]
)
