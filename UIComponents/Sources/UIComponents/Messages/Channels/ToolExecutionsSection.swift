import Abstractions
import Database
import SwiftUI

private enum SectionConstants {
    static let sectionSpacing: CGFloat = 8
    static let toolRowSpacing: CGFloat = 4
    static let toolIndentation: CGFloat = 20
    static let animationDuration: Double = 0.2
}

internal struct ToolExecutionsSection: View {
    let toolExecutions: [ToolExecution]
    @State private var isExpanded: Bool = false

    internal var body: some View {
        VStack(alignment: .leading, spacing: SectionConstants.sectionSpacing) {
            toolHeader
            if isExpanded {
                toolsList
            }
        }
    }

    private var toolHeader: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)
            Text(String(localized: "Tools Used", bundle: .module))
                .font(.caption)
                .foregroundColor(.textSecondary)
            Spacer()
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(
                .easeInOut(duration: SectionConstants.animationDuration)
            ) {
                isExpanded.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            isExpanded
                ? String(localized: "Collapse tools list", bundle: .module)
                : String(localized: "Expand tools list", bundle: .module)
        )
    }

    private var toolsList: some View {
        VStack(
            alignment: .leading,
            spacing: SectionConstants.toolRowSpacing
        ) {
            ForEach(toolExecutions, id: \.id) { execution in
                ToolExecutionRow(toolExecution: execution)
            }
        }
        .padding(.leading, SectionConstants.toolIndentation)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Tool Executions Section") {
        @Previewable @State var toolExecutions: [ToolExecution] = [
            ToolExecution(
                request: ToolRequest(
                    name: "calculator",
                    arguments: "{\"expression\": \"42 * 3.14159\"}",
                    displayName: "Calculator"
                ),
                state: .completed
            ),
            ToolExecution(
                request: ToolRequest(
                    name: "web_search",
                    arguments: "{\"query\": \"Swift concurrency\"}",
                    displayName: "Web Search"
                ),
                state: .executing
            ),
            ToolExecution(
                request: ToolRequest(
                    name: "file_read",
                    arguments: "{\"path\": \"/example.txt\"}",
                    displayName: "Read File"
                ),
                state: .failed
            )
        ]

        ToolExecutionsSection(toolExecutions: toolExecutions)
            .padding()
    }
#endif
