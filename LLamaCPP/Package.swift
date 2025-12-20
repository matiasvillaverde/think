// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLamaCPP",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "LLamaCPP",
            targets: ["LLamaCPP"])
    ],
    dependencies: [
        .package(path: "../Abstractions")
    ],
    targets: [
        // Add the binary target for llama.cpp XCFramework
        .binaryTarget(
            name: "llama",
            url:
                "https://github.com/ggml-org/llama.cpp/releases/download/b6102/llama-b6102-xcframework.zip",
            checksum: "257b8ffbdda68b377e1b75cd23055b201b0e9a24e18d5a42f2960456776eab8a"
        ),
        .target(
            name: "LLamaCPP",
            dependencies: [
                "Abstractions",
                "llama",  // Add llama as a dependency
            ],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
        .testTarget(
            name: "LLamaCPPTests",
            dependencies: [
                "LLamaCPP",
                .product(
                    name: "AbstractionsTestUtilities",
                    package: "Abstractions"
                ),
            ],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
