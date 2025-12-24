// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rag",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Rag",
            targets: ["Rag"]
        )
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(url: "https://github.com/jkrukowski/SQLiteVec", from: "0.0.14"),
        .package(url: "https://github.com/jkrukowski/swift-embeddings", from: "0.0.20")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Rag",
            dependencies: [
                "Abstractions",
                .product(name: "SQLiteVec", package: "SQLiteVec"),
                .product(name: "Embeddings", package: "swift-embeddings")
            ],
        ),
        .testTarget(
            name: "RagTests",
            dependencies: [
                "Rag",
                .product(
                    name: "AbstractionsTestUtilities",
                    package: "Abstractions"
                )
            ],
            resources: [
                .copy("all-MiniLM-L6-v2"),
                .copy("Fixtures")
            ]
        )
    ]
)
