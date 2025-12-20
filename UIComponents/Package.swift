// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UIComponents",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "UIComponents",
            targets: ["UIComponents"])
    ],
    dependencies: [
        .package(path: "../Abstractions"),
        .package(path: "../DataAssets"),
        .package(path: "../Database"),
        .package(path: "../RemoteSession"),
        .package(url: "https://github.com/siteline/swiftui-introspect", from: "26.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
        .package(url: "https://github.com/raspu/Highlightr/", from: "2.3.0"),
        .package(url: "https://github.com/vibeprogrammer/LaTeXSwiftUI", branch: "main"),
        .package(url: "https://github.com/CSolanaM/SkeletonUI.git", branch: "master"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.6.2")
    ],
    targets: [
        .target(
            name: "UIComponents",
            dependencies: [
                "Abstractions",
                "DataAssets",
                "Database",
                "RemoteSession",
                .product(name: "SwiftUIIntrospect", package: "swiftui-introspect"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Highlightr", package: "Highlightr"),
                .product(name: "LaTeXSwiftUI", package: "LaTeXSwiftUI"),
                .product(name: "SkeletonUI", package: "SkeletonUI"),
                .product(name: "Kingfisher", package: "Kingfisher")
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/Localizable.xcstrings")
            ],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
        .testTarget(
            name: "UIComponentsTests",
            dependencies: [
                "UIComponents"
            ]
        )
    ]
)
