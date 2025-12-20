import SwiftUI

/// Color constants for architecture logos
private enum Colors {
    static let redZero: Double = 0.0
    static let redLow: Double = 0.1
    static let redMedium: Double = 0.3
    static let redHigh: Double = 0.5
    static let redVeryHigh: Double = 0.7
    static let redExtreme: Double = 0.8
    static let redMax: Double = 0.9
    static let redSuper: Double = 0.95

    static let greenZero: Double = 0.0
    static let greenLow: Double = 0.1
    static let greenMedium: Double = 0.3
    static let greenHigh: Double = 0.5
    static let greenVeryHigh: Double = 0.7
    static let greenExtreme: Double = 0.8
    static let greenMax: Double = 0.9
    static let greenSuper: Double = 0.95

    static let blueLow: Double = 0.1
    static let blueMedium: Double = 0.3
    static let blueHigh: Double = 0.6
    static let blueVeryHigh: Double = 0.7
    static let blueExtreme: Double = 0.8
    static let blueMax: Double = 0.9
    static let blueSuper: Double = 0.95
}

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
            (
                Color(red: Colors.redLow, green: Colors.greenHigh, blue: Colors.blueExtreme),
                Color(red: Colors.redHigh, green: Colors.greenExtreme, blue: Colors.blueMax)
            )

        case let name where name.contains("mistral") || name.contains("mixtral"):
            (
                Color(red: Colors.redExtreme, green: Colors.greenMedium, blue: Colors.redLow),
                Color(red: Colors.redMax, green: Colors.greenVeryHigh, blue: Colors.redHigh)
            )

        case let name where name.contains("gemini"):
            (
                Color(red: Colors.redLow, green: Colors.greenExtreme, blue: Colors.blueExtreme),
                Color(red: Colors.redHigh, green: Colors.greenMax, blue: Colors.blueMax)
            )

        case let name where name.contains("gemma"):
            (
                Color(red: Colors.redHigh, green: Colors.redLow, blue: Colors.blueExtreme),
                Color(red: Colors.greenExtreme, green: Colors.redHigh, blue: Colors.blueMax)
            )

        case let name where name.contains("llama"):
            (
                Color(red: Colors.redLow, green: Colors.greenVeryHigh, blue: Colors.blueMax),
                Color(red: Colors.redHigh, green: Colors.greenMax, blue: Colors.blueSuper)
            )

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
            (
                Color(
                    red: Colors.greenZero,
                    green: Colors.greenVeryHigh,
                    blue: Colors.blueVeryHigh
                ),
                Color(red: Colors.redLow, green: Colors.greenMax, blue: Colors.blueExtreme)
            )

        case let name where name.contains("qwen"):
            (
                Color(red: Colors.redLow, green: Colors.greenHigh, blue: Colors.blueExtreme),
                Color(red: Colors.redHigh, green: Colors.greenExtreme, blue: Colors.blueMax)
            )

        case let name where name.contains("claude"):
            (
                Color(red: Colors.redExtreme, green: Colors.redHigh, blue: Colors.redLow),
                Color(red: Colors.redMax, green: Colors.greenExtreme, blue: Colors.redHigh)
            )

        case let name where name.contains("gpt"):
            (
                Color(red: Colors.redLow, green: Colors.greenMax, blue: Colors.redHigh),
                Color(red: Colors.redHigh, green: Colors.greenSuper, blue: Colors.greenExtreme)
            )

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
            Color(red: Colors.greenMedium, green: Colors.greenMedium, blue: Colors.redHigh),
            Color(red: Colors.greenVeryHigh, green: Colors.greenVeryHigh, blue: Colors.greenExtreme)
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
                    Color.clear,
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
