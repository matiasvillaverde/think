import SwiftUI

/// Provides logo assets or SF Symbols for model architectures
internal enum ArchitectureLogoProvider {
    /// Logo source type
    enum LogoSource {
        case asset(String)
        case sfSymbol(String)
        case unavailable
    }

    /// Get logo source for a given model name
    static func logo(for modelName: String) -> LogoSource {
        let lowercased: String = modelName.lowercased()

        // Check for asset-based logos first
        if let assetLogo = checkAssetLogo(for: lowercased) {
            return assetLogo
        }

        // Check for SF Symbol logos
        if let sfSymbolLogo = checkSFSymbolLogo(for: lowercased) {
            return sfSymbolLogo
        }

        // Default fallback
        return .sfSymbol("brain")
    }

    private static func checkAssetLogo(for name: String) -> LogoSource? {
        switch name.lowercased() {
        case let name where name.contains("deepseek"):
            .asset("deepseek")

        case let name where name.contains("mistral") || name.contains("mixtral"):
            .asset("mistral")

        case let name where name.contains("gemini"):
            .asset("gemini")

        case let name where name.contains("gemma"):
            .asset("gemma")

        case let name where name.contains("llama"):
            .asset("meta")

        case let name where name.contains("phi"):
            .asset("microsoft")

        case let name where name.contains("qwen"):
            .asset("qwen")

        default:
            nil
        }
    }

    private static func checkSFSymbolLogo(for name: String) -> LogoSource? {
        // First batch of symbols
        if let symbol = checkCommonModels(for: name) {
            return symbol
        }

        // Second batch of symbols
        if let symbol = checkSpecializedModels(for: name) {
            return symbol
        }

        return nil
    }

    private static func checkCommonModels(for name: String) -> LogoSource? {
        switch name {
        case let name where name.contains("llama"):
            .sfSymbol("llama.fill")

        case let name where name.contains("gemma"):
            .sfSymbol("diamond.fill")

        case let name where name.contains("phi"):
            .sfSymbol("greek.phi.circle.fill")

        case let name where name.contains("gpt"):
            .sfSymbol("cpu.fill")

        case let name where name.contains("claude"):
            .sfSymbol("brain.head.profile.fill")

        default:
            nil
        }
    }

    private static func checkSpecializedModels(for name: String) -> LogoSource? {
        // Check research models first
        if let symbol = checkResearchModels(for: name) {
            return symbol
        }

        // Check specialized domain models
        if let symbol = checkDomainModels(for: name) {
            return symbol
        }

        return nil
    }

    private static func checkResearchModels(for name: String) -> LogoSource? {
        switch name {
        case let name where name.contains("deepseek"):
            .sfSymbol("magnifyingglass.circle.fill")

        case let name where name.contains("yi"):
            .sfSymbol("y.circle.fill")

        case let name where name.contains("falcon"):
            .sfSymbol("bird.fill")

        case let name where name.contains("bert"):
            .sfSymbol("b.circle.fill")

        case let name where name.contains("t5"):
            .sfSymbol("5.circle.fill")

        default:
            nil
        }
    }

    private static func checkDomainModels(for name: String) -> LogoSource? {
        switch name {
        case let name where name.contains("whisper"):
            .sfSymbol("waveform.circle.fill")

        case let name where name.contains("stable-diffusion") || name.contains("sd"):
            .sfSymbol("photo.artframe")

        case let name where name.contains("flux"):
            .sfSymbol("sparkles.rectangle.stack.fill")

        case let name where name.contains("chat"):
            .sfSymbol("message.circle.fill")

        case let name where name.contains("code"):
            .sfSymbol("chevron.left.forwardslash.chevron.right")

        default:
            nil
        }
    }

    /// Create a logo view for the given source
    @ViewBuilder
    static func logoView(for source: LogoSource) -> some View {
        switch source {
        case let .asset(name):
            Image(name, bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: DiscoveryConstants.Card.logoIconSize,
                    height: DiscoveryConstants.Card.logoIconSize
                )

        case let .sfSymbol(name):
            Image(systemName: name)
                .font(.system(
                    size: DiscoveryConstants.Card.logoIconSize
                        * DiscoveryConstants.FontSize.logoMultiplier,
                    weight: .medium,
                    design: .rounded
                ))
                .symbolRenderingMode(.hierarchical)

        case .unavailable:
            EmptyView()
        }
    }

    /// Get brand colors for popular models
    private static func getPopularModelColors(
        for name: String
    ) -> (primary: Color, secondary: Color)? {
        switch name {
        case let name where name.contains("deepseek"):
            (Color.brandDeepseekPrimary, Color.brandDeepseekSecondary)

        case let name where name.contains("mistral") || name.contains("mixtral"):
            (Color.brandMistralPrimary, Color.brandMistralSecondary)

        case let name where name.contains("gemini"):
            (Color.brandGeminiPrimary, Color.brandGeminiSecondary)

        case let name where name.contains("gemma"):
            (Color.brandGemmaPrimary, Color.brandGemmaSecondary)

        case let name where name.contains("llama"):
            (Color.brandLlamaPrimary, Color.brandLlamaSecondary)

        default:
            nil
        }
    }

    /// Get brand colors for other models
    private static func getOtherModelColors(
        for name: String
    ) -> (primary: Color, secondary: Color)? {
        switch name {
        case let name where name.contains("phi"):
            (Color.brandPhiPrimary, Color.brandPhiSecondary)

        case let name where name.contains("qwen"):
            (Color.brandQwenPrimary, Color.brandQwenSecondary)

        case let name where name.contains("claude"):
            (Color.brandClaudePrimary, Color.brandClaudeSecondary)

        case let name where name.contains("gpt"):
            (Color.brandGptPrimary, Color.brandGptSecondary)

        default:
            nil
        }
    }

    /// Get brand colors for a given model name
    private static func brandColors(for modelName: String) -> (primary: Color, secondary: Color) {
        let lowercased: String = modelName.lowercased()

        // Check popular models first
        if let colors = getPopularModelColors(for: lowercased) {
            return colors
        }

        // Check other models
        if let colors = getOtherModelColors(for: lowercased) {
            return colors
        }

        // Default colors
        return (
            Color.brandDefaultPrimary,
            Color.brandDefaultSecondary
        )
    }

    /// Gradient constants
    private enum GradientConstants {
        static let radialStartRadius: CGFloat = 20
        static let radialEndRadius: CGFloat = 80
        static let logoScale: CGFloat = 1.4
    }

    /// Create a styled logo container with background
    @ViewBuilder
    static func styledLogoView(for modelName: String) -> some View {
        let logoSource: LogoSource = logo(for: modelName)
        let colors: (primary: Color, secondary: Color) = brandColors(for: modelName)

        ZStack {
            // Brand-colored gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    colors.primary.opacity(DiscoveryConstants.Opacity.medium),
                    colors.secondary.opacity(DiscoveryConstants.Opacity.light)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle radial gradient overlay for depth
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.paletteClear,
                    colors.primary.opacity(DiscoveryConstants.Opacity.extraLight)
                ]),
                center: .center,
                startRadius: GradientConstants.radialStartRadius,
                endRadius: GradientConstants.radialEndRadius
            )

            // Logo - larger and more prominent
            logoView(for: logoSource)
                .scaleEffect(GradientConstants.logoScale)
                .foregroundColor(.white.opacity(DiscoveryConstants.Opacity.extraStrong))
        }
        .frame(
            width: DiscoveryConstants.Card.width,
            height: DiscoveryConstants.Card.imageSize.height
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: DesignConstants.Radius.standard,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: DesignConstants.Radius.standard
            )
        )
    }
}
