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
        .package(path: "../Abstractions")
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
                .product(
                    name: "AbstractionsTestUtilities",
                    package: "Abstractions"
                )
            ]
        )
    ]
)
