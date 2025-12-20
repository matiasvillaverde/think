import Abstractions
import Database
import SwiftUI

private enum ToolRowConstants {
    static let sectionSpacing: CGFloat = 8
    static let toolRowSpacing: CGFloat = 4
    static let toolIndentation: CGFloat = 20
    static let animationDuration: Double = 0.2
    static let iconOpacity: Double = 0.6
    static let toolTextSpacing: CGFloat = 2
    static let progressViewScale: CGFloat = 0.7
    static let requestingOpacity: Double = 0.5
}

internal struct ToolExecutionRow: View {
    internal let toolExecution: ToolExecution

    internal var body: some View {
        HStack(alignment: .top, spacing: ToolRowConstants.toolRowSpacing) {
            toolStatusIcon
            toolContent
            Spacer()
            toolStatusIndicator
        }
        .animation(
            .easeInOut(duration: ToolRowConstants.animationDuration),
            value: toolExecution.state
        )
    }

    @ViewBuilder private var toolStatusIcon: some View {
        Image(systemName: statusIconName)
            .font(.caption2)
            .foregroundColor(statusColor)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var toolContent: some View {
        VStack(
            alignment: .leading,
            spacing: ToolRowConstants.toolTextSpacing
        ) {
            Text(toolExecution.request?.displayName ?? toolExecution.toolName)
                .font(.caption)
                .fontWeight(.medium)

            // Show error message if failed
            if toolExecution.state == .failed, let errorMessage = toolExecution.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder private var toolStatusIndicator: some View {
        switch toolExecution.state {
        case .executing:
            ProgressView()
                .scaleEffect(ToolRowConstants.progressViewScale)
                .accessibilityLabel(String(localized: "In progress", bundle: .module))

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(String(localized: "Completed", bundle: .module))

        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(String(localized: "Failed", bundle: .module))

        case .parsing, .pending:
            EmptyView()
        }
    }

    private var statusIconName: String {
        switch toolExecution.state {
        case .parsing, .pending:
            return "arrow.right.circle"

        case .executing:
            return "arrow.right.circle.fill"

        case .completed:
            return "checkmark.circle.fill"

        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch toolExecution.state {
        case .parsing, .pending:
            return .blue.opacity(ToolRowConstants.requestingOpacity)

        case .executing:
            return .blue.opacity(ToolRowConstants.iconOpacity)

        case .completed:
            return .green

        case .failed:
            return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Tool Executing") {
        ToolExecutionRow(
            toolExecution: ToolExecution(
                request: ToolRequest(
                    name: "web_search",
                    arguments: "{\"query\": \"Swift concurrency\"}",
                    displayName: "Web Search"
                ),
                state: .executing
            )
        )
        .padding()
    }

    #Preview("Tool Completed") {
        ToolExecutionRow(
            toolExecution: ToolExecution(
                request: ToolRequest(
                    name: "calculator",
                    arguments: "{\"expression\": \"42 * 3.14159\"}",
                    displayName: "Calculator"
                ),
                state: .completed
            )
        )
        .padding()
    }

    #Preview("Tool Failed") {
        let toolExecution: ToolExecution = ToolExecution(
            request: ToolRequest(
                name: "api_call",
                arguments: "{\"endpoint\": \"/invalid\"}",
                displayName: "API Call"
            ),
            state: .failed
        )
        // Note: errorMessage would be set by the fail command in real usage
        ToolExecutionRow(toolExecution: toolExecution)
            .padding()
    }
#endif
