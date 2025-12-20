import Database
import SwiftUI

// MARK: - ToolUsageView

public struct ToolUsageView: View {
    @Bindable var toolExecution: ToolExecution
    @State private var isExpanded: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            ToolHeaderView(
                toolName: toolExecution.toolName,
                hasResult: toolExecution.response != nil,
                isExpanded: isExpanded
            )
            .contentShape(Rectangle()) // This ensures the entire area is tappable
            .onTapGesture {
                withAnimation(.easeInOut(duration: ToolUsageConstants.animationDuration)) {
                    isExpanded.toggle()
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(
                String(
                    localized: "Expanded tool usage for \(toolExecution.toolName)",
                    bundle: .module
                )
            )

            // Expanded content
            if isExpanded {
                ToolExpandedContent(
                    toolRequest: toolExecution.request,
                    toolResponse: toolExecution.response
                )
            }
        }
        .background(Color.backgroundPrimary)
        .cornerRadius(ToolUsageConstants.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ToolUsageConstants.cornerRadius)
                .stroke(Color.backgroundSecondary, lineWidth: ToolUsageConstants.borderWidth)
        )
    }
}
