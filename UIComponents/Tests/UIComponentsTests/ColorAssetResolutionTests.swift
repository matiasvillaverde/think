import Foundation
import Testing

@testable import UIComponents

@Suite
internal struct ColorAssetResolutionTests {
    private enum Constants {
        static let assetCatalogURL: URL = {
            let uiComponentsRoot: URL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // UIComponentsTests
                .deletingLastPathComponent()  // Tests
                .deletingLastPathComponent()  // UIComponents
            return uiComponentsRoot.appendingPathComponent(
                "Sources/UIComponents/Resources/Assets.xcassets"
            )
        }()

        static let assetNames: [String] = [
            // Existing palette
            "AccentColor",
            "BackgroundPrimary",
            "BackgroundSecondary",
            "IconPrimary",
            "IconSecondary",
            "IconHovered",
            "TextPrimary",
            "TextSecondary",
            "marketingPrimary",
            "marketingSecondary",
            "headerBackground",
            "containerBackground",
            "buttonStroke",

            // Base palette
            "PaletteBlack",
            "PaletteWhite",
            "PaletteClear",
            "PaletteGray",
            "PaletteBlue",
            "PaletteGreen",
            "PaletteOrange",
            "PaletteRed",
            "PalettePurple",

            // Brand colors
            "BrandDefaultPrimary",
            "BrandDefaultSecondary",
            "BrandClaudePrimary",
            "BrandClaudeSecondary",
            "BrandDeepseekPrimary",
            "BrandDeepseekSecondary",
            "BrandGeminiPrimary",
            "BrandGeminiSecondary",
            "BrandGemmaPrimary",
            "BrandGemmaSecondary",
            "BrandGptPrimary",
            "BrandGptSecondary",
            "BrandLlamaPrimary",
            "BrandLlamaSecondary",
            "BrandMistralPrimary",
            "BrandMistralSecondary",
            "BrandPhiPrimary",
            "BrandPhiSecondary",
            "BrandQwenPrimary",
            "BrandQwenSecondary"
        ]
    }

    @Test
    func allAssetBackedColorTokensResolve() {
        for name in Constants.assetNames {
            #expect(assetColorExists(named: name), "Missing color asset: \(name)")
        }
    }

    private func assetColorExists(named name: String) -> Bool {
        let colorsetURL: URL = Constants.assetCatalogURL.appendingPathComponent("\(name).colorset")
        let contentsURL: URL = colorsetURL.appendingPathComponent("Contents.json")
        return FileManager.default.fileExists(atPath: contentsURL.path)
    }
}
