// Color.swift
import SwiftUI

extension Color {
    // System colors
    /// The primary accent color for the application
    static let accentColor: Color = .init("AccentColor", bundle: .module)

    // Palette (base colors)
    ///
    /// These are provided for cases where the UI needs a "basic color" (e.g. chart lines, badges),
    /// but we still want all color values to be sourced from `Assets.xcassets`.
    static let paletteBlack: Color = .init("PaletteBlack", bundle: .module)
    static let paletteWhite: Color = .init("PaletteWhite", bundle: .module)
    static let paletteClear: Color = .init("PaletteClear", bundle: .module)
    static let paletteGray: Color = .init("PaletteGray", bundle: .module)
    static let paletteBlue: Color = .init("PaletteBlue", bundle: .module)
    static let paletteGreen: Color = .init("PaletteGreen", bundle: .module)
    static let paletteOrange: Color = .init("PaletteOrange", bundle: .module)
    static let paletteRed: Color = .init("PaletteRed", bundle: .module)
    static let palettePurple: Color = .init("PalettePurple", bundle: .module)

    // Background colors
    /// Primary background color for main content areas
    static let backgroundPrimary: Color = .init("BackgroundPrimary", bundle: .module)
    /// Secondary background color for supporting content areas
    static let backgroundSecondary: Color = .init("BackgroundSecondary", bundle: .module)
    /// Background color specifically for card components
    static let backgroundCard: Color = backgroundSecondary

    // Icon colors
    /// Primary color for standard icons
    static let iconPrimary: Color = .init("IconPrimary", bundle: .module)
    /// Color for alert and error icons
    static let iconAlert: Color = paletteRed
    /// Color for confirmation and success icons
    static let iconConfirmation: Color = paletteGreen
    /// Color for warning icons
    static let iconWarning: Color = paletteOrange
    /// Color for informational icons
    static let iconInfo: Color = paletteBlue
    /// Color for icons in hover state
    static let iconHovered: Color = .init("IconHovered", bundle: .module)
    /// Secondary color for less prominent icons
    static let iconSecondary: Color = .init("IconSecondary", bundle: .module)

    // Text colors
    /// Primary text color for main content
    static let textPrimary: Color = .init("TextPrimary", bundle: .module)
    /// Secondary text color for supporting content
    static let textSecondary: Color = .init("TextSecondary", bundle: .module)

    // Marketing colors
    /// Primary color for marketing and promotional content
    static let marketingPrimary: Color = .init("marketingPrimary", bundle: .module)
    /// Secondary color for marketing and promotional content
    static let marketingSecondary: Color = .init("marketingSecondary", bundle: .module)
    /// Text color for marketing secondary backgrounds
    static let marketingSecondaryText: Color = paletteWhite

    // Code colors
    /// Background color for header sections
    static let headerBackground: Color = .init("headerBackground", bundle: .module)
    /// Background color for container elements
    static let containerBackground: Color = .init("containerBackground", bundle: .module)
    /// Stroke color for button borders
    static let buttonStroke: Color = .init("buttonStroke", bundle: .module)

    // Brand (architecture/model logos)
    static let brandDefaultPrimary: Color = .init("BrandDefaultPrimary", bundle: .module)
    static let brandDefaultSecondary: Color = .init("BrandDefaultSecondary", bundle: .module)

    static let brandClaudePrimary: Color = .init("BrandClaudePrimary", bundle: .module)
    static let brandClaudeSecondary: Color = .init("BrandClaudeSecondary", bundle: .module)
    static let brandDeepseekPrimary: Color = .init("BrandDeepseekPrimary", bundle: .module)
    static let brandDeepseekSecondary: Color = .init("BrandDeepseekSecondary", bundle: .module)
    static let brandGeminiPrimary: Color = .init("BrandGeminiPrimary", bundle: .module)
    static let brandGeminiSecondary: Color = .init("BrandGeminiSecondary", bundle: .module)
    static let brandGemmaPrimary: Color = .init("BrandGemmaPrimary", bundle: .module)
    static let brandGemmaSecondary: Color = .init("BrandGemmaSecondary", bundle: .module)
    static let brandGptPrimary: Color = .init("BrandGptPrimary", bundle: .module)
    static let brandGptSecondary: Color = .init("BrandGptSecondary", bundle: .module)
    static let brandLlamaPrimary: Color = .init("BrandLlamaPrimary", bundle: .module)
    static let brandLlamaSecondary: Color = .init("BrandLlamaSecondary", bundle: .module)
    static let brandMistralPrimary: Color = .init("BrandMistralPrimary", bundle: .module)
    static let brandMistralSecondary: Color = .init("BrandMistralSecondary", bundle: .module)
    static let brandPhiPrimary: Color = .init("BrandPhiPrimary", bundle: .module)
    static let brandPhiSecondary: Color = .init("BrandPhiSecondary", bundle: .module)
    static let brandQwenPrimary: Color = .init("BrandQwenPrimary", bundle: .module)
    static let brandQwenSecondary: Color = .init("BrandQwenSecondary", bundle: .module)
}
