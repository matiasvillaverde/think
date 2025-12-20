// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tools",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "Tools",
            targets: ["Tools"])
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(path: "../Database"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.11.3")
    ],
    targets: [
        .target(
            name: "Tools",
            dependencies: [
                "Abstractions",
                "Database",
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]),
        .testTarget(
            name: "ToolsTests",
            dependencies: [
                "Tools",
                .product(name: "AbstractionsTestUtilities", package: "Abstractions")
            ]
        )
    ]
)
