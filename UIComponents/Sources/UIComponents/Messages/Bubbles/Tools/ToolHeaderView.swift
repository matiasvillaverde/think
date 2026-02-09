import SwiftUI

// **MARK: - ToolHeaderView**
public struct ToolHeaderView: View {
    let toolName: String
    let hasResult: Bool
    let isExpanded: Bool

    public var body: some View {
        HStack {
            toolIcon()
            toolNameLabel()
            Spacer()
            statusIndicator()
            expandCollapseIcon()
        }
        .padding(.vertical, ToolUsageConstants.headerVerticalPadding)
        .padding(.horizontal, ToolUsageConstants.headerHorizontalPadding)
        .background(Color.paletteClear)
    }

    // MARK: - Private UI Components

    private func toolIcon() -> some View {
        Image(systemName: "wrench")
            .foregroundColor(Color.textSecondary)
            .accessibilityLabel(
                String(
                    localized: "Tool icon",
                    bundle: .module
                )
            )
    }

    private func toolNameLabel() -> some View {
        Text("Using tool: \(toolName)", bundle: .module)
            .font(.system(
                size: ToolUsageConstants.headerFontSize,
                weight: .medium
            ))
            .foregroundColor(Color.textPrimary)
    }

    private func statusIndicator() -> some View {
        Group {
            if hasResult {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.iconConfirmation)
                    .accessibilityLabel(
                        String(
                            localized: "Tool has completed",
                            bundle: .module
                        )
                    )
            } else {
                ProgressView()
                    .foregroundColor(Color.iconPrimary)
                    .frame(
                        width: ToolUsageConstants.statusIconSize,
                        height: ToolUsageConstants.statusIconSize
                    )
            }
        }
    }

    private func expandCollapseIcon() -> some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundColor(Color.textSecondary)
            .padding(.leading, ToolUsageConstants.headerSpacing)
            .accessibilityLabel(
                String(
                    localized: "Expand/collapse tool details",
                    bundle: .module
                )
            )
    }
}
