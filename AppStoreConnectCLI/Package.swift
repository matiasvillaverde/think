// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppStoreConnectCLI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .executable(
            name: "app-store-cli",
            targets: ["AppStoreConnectCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk", from: "3.6.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "AppStoreConnectCLI",
            dependencies: [
                .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
        .testTarget(
            name: "AppStoreConnectCLITests",
            dependencies: [
                "AppStoreConnectCLI"
            ],
            path: "Tests/AppStoreConnectCLITests"
        ),
        .testTarget(
            name: "AcceptanceTests",
            dependencies: [
                "AppStoreConnectCLI"
            ],
            path: "Tests/AcceptanceTests",
            swiftSettings: [
                .define("ACCEPTANCE_TESTS")
            ]
        )
    ]
)
