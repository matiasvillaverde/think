// Color.swift
import SwiftUI

extension Color {
    // System colors
    /// The primary accent color for the application
    static let accentColor: Color = .init("AccentColor", bundle: .module)

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
    static let iconAlert: Color = .red
    /// Color for confirmation and success icons
    static let iconConfirmation: Color = .green
    /// Color for warning icons
    static let iconWarning: Color = .orange
    /// Color for informational icons
    static let iconInfo: Color = .blue
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
    static let marketingSecondaryText: Color = .white

    // Code colors
    /// Background color for header sections
    static let headerBackground: Color = .init("headerBackground", bundle: .module)
    /// Background color for container elements
    static let containerBackground: Color = .init("containerBackground", bundle: .module)
    /// Stroke color for button borders
    static let buttonStroke: Color = .init("buttonStroke", bundle: .module)
}
