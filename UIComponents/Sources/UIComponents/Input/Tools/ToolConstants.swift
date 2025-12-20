import Foundation

internal enum ToolConstants {
    // MARK: - Layout

    static let horizontalSpacing: CGFloat = 8
    static let verticalSpacing: CGFloat = 6

    // MARK: - Tool Chips

    static let chipHorizontalPadding: CGFloat = 12
    static let chipVerticalPadding: CGFloat = 6
    static let chipIconSize: CGFloat = 14
    static let chipRemoveIconSize: CGFloat = 12
    static let chipSpacing: CGFloat = 8

    // MARK: - Tool Button

    static let toolsButtonSize: CGFloat = 44
    static let toolsButtonIconSize: CGFloat = 16

    // MARK: - Tool Sheet

    static let sheetSpacing: CGFloat = 20
    static let rowSpacing: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 8
    static let rowIconSize: CGFloat = 20
    static let rowIconFrame: CGFloat = 24
    static let rowTextSize: CGFloat = 16

    // MARK: - Popover (macOS)

    static let popoverMinWidth: CGFloat = 350
    static let popoverMinHeight: CGFloat = 300
    static let popoverTitleVerticalPadding: CGFloat = 12

    // MARK: - Animation

    static let animationDuration: CGFloat = 0.2

    // MARK: - Memory Requirements

    static let minimumMemoryToDraw: UInt64 = 7_073_741_824 // 7GB
    static let minimumMemoryToReason: UInt64 = 5_073_741_824 // 5GB
}
