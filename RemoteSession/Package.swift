// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemoteSession",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "RemoteSession",
            targets: ["RemoteSession"])
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(path: "../ContextBuilder")
    ],
    targets: [
        .target(
            name: "RemoteSession",
            dependencies: [
                "Abstractions"
            ]
        ),
        .testTarget(
            name: "RemoteSessionTests",
            dependencies: [
                "RemoteSession",
                "ContextBuilder",
                .product(
                    name: "AbstractionsTestUtilities",
                    package: "Abstractions"
                )
            ]
        )
    ]
)
