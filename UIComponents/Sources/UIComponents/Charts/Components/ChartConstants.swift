import SwiftUI

/// Centralized styling constants for chart components
public enum ChartConstants {
    // MARK: - Layout

    /// Layout constants for charts
    public enum Layout {
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 20
        static let headerSpacing: CGFloat = 8
        static let itemSpacing: CGFloat = 4
        static let defaultMaxColumns: Int = 4

        // Chart specific
        static let chartHeight: CGFloat = 300
        static let compactChartHeight: CGFloat = 200
        static let expandedChartHeight: CGFloat = 400
        static let minChartHeight: CGFloat = 150

        // Platform adaptive
        #if os(iOS)
            static let horizontalPadding: CGFloat = 16
            static let verticalPadding: CGFloat = 12
        #elseif os(macOS)
            static let horizontalPadding: CGFloat = 20
            static let verticalPadding: CGFloat = 16
        #else
            static let horizontalPadding: CGFloat = 20
            static let verticalPadding: CGFloat = 16
        #endif
    }

    // MARK: - Styling

    /// Styling constants for charts
    public enum Styling {
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let shadowOpacity: Double = 0.1
        static let borderWidth: CGFloat = 1
        static let separatorOpacity: Double = 0.2

        // Opacity constants
        static let borderOpacity: Double = 0.2

        // Animation
        static let animationDuration: Double = 0.3
        static let springResponse: Double = 0.8
        static let springDamping: Double = 0.8
        static let staggerDelay: Double = 0.05
        static let entryAnimationResponse: Double = 0.6
        static let entryAnimationDamping: Double = 0.8
        static let initialScale: Double = 0.95

        // Colors
        #if os(iOS)
            static let cardBackground: Color = .init(UIColor.systemBackground)
            static let cardBorder: Color = .init(UIColor.separator).opacity(borderOpacity)
            static let sectionHeader: Color = .init(UIColor.secondaryLabel)
        #elseif os(macOS)
            static let cardBackground: Color = .init(NSColor.windowBackgroundColor)
            static let cardBorder: Color = .init(NSColor.separatorColor).opacity(borderOpacity)
            static let sectionHeader: Color = .init(NSColor.secondaryLabelColor)
        #else
            static let cardBackground: Color = .white
            static let cardBorder: Color = .gray.opacity(borderOpacity)
            static let sectionHeader: Color = .gray
        #endif
    }

    // MARK: - Typography

    /// Typography constants for charts
    public enum Typography {
        static let chartTitleSize: CGFloat = 18
        static let chartSubtitleSize: CGFloat = 14
        static let sectionHeaderSize: CGFloat = 20
        static let labelSize: CGFloat = 12
        static let valueSize: CGFloat = 14
    }

    // MARK: - Grid

    /// Grid layout constants
    public enum Grid {
        static let minColumnWidth: CGFloat = 300
        static let maxColumnWidth: CGFloat = 500
        static let idealColumnWidth: CGFloat = 400

        static let phoneBreakpoint: CGFloat = 600
        static let tabletBreakpoint: CGFloat = 900
        static let desktopSmallBreakpoint: CGFloat = 700
        static let desktopMediumBreakpoint: CGFloat = 1_200
        static let desktopLargeBreakpoint: CGFloat = 1_800

        // Column count constants
        static let singleColumn: Int = 1
        static let twoColumns: Int = 2
        static let threeColumns: Int = 3

        #if os(iOS)
            static func columnsForWidth(_ width: CGFloat) -> Int {
                if width < phoneBreakpoint {
                    return singleColumn
                }
                if width < tabletBreakpoint {
                    return twoColumns
                }
                return threeColumns
            }
        #else
            static func columnsForWidth(_ width: CGFloat) -> Int {
                if width < desktopSmallBreakpoint {
                    return singleColumn
                }
                if width < desktopMediumBreakpoint {
                    return twoColumns
                }
                if width < desktopLargeBreakpoint {
                    return threeColumns
                }
                return Layout.defaultMaxColumns
            }
        #endif
    }

    // MARK: - Interaction

    /// Interaction constants
    public enum Interaction {
        static let tapTargetSize: CGFloat = 44
        static let sliderHeight: CGFloat = 20
        static let toggleWidth: CGFloat = 51
        static let buttonPaddingValue: CGFloat = 8
        static let buttonPaddingHorizontal: CGFloat = 12
        static let buttonPadding: EdgeInsets = .init(
            top: buttonPaddingValue,
            leading: buttonPaddingHorizontal,
            bottom: buttonPaddingValue,
            trailing: buttonPaddingHorizontal
        )
    }
}
