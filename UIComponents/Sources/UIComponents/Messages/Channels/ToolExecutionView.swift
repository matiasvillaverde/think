import Abstractions
import Database
import MarkdownUI
import SwiftUI

/// Enhanced tool execution view with expandable results and source display
internal struct ToolExecutionView: View {
    // MARK: - Constants

    private enum Constants {
        static let cornerRadius: CGFloat = 8
        static let padding: CGFloat = 12
        static let spacing: CGFloat = 8
        static let headerSpacing: CGFloat = 6
        static let iconSize: CGFloat = 14
        static let animationDuration: Double = 0.2
        static let borderWidth: CGFloat = 1
        static let borderOpacity: Double = 0.2
        static let backgroundOpacity: Double = 0.03
        static let progressScale: CGFloat = 0.8
        static let resultMaxHeight: CGFloat = 300
        static let iconOpacity: Double = 0.7
        static let chevronSize: CGFloat = 12
        static let resultPadding: CGFloat = 8
        static let resultCornerRadius: CGFloat = 6
        static let resultBackgroundOpacity: Double = 0.05
        static let secondaryOpacity: Double = 0.5
        static let animationResponse: Double = 0.3
        static let animationDamping: Double = 0.8
        static let resultSpacing: CGFloat = 4
        static let errorSpacing: CGFloat = 6
        static let iconSizeReduction: CGFloat = 2
    }

    // MARK: - Properties

    @Bindable var toolExecution: ToolExecution
    @State private var isExpanded: Bool = false
    @State private var showRawJSON: Bool = false

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch toolExecution.state {
        case .parsing, .pending:
            return .gray

        case .executing:
            return .blue

        case .completed:
            return .green

        case .failed:
            return .red
        }
    }

    private var statusIcon: String {
        switch toolExecution.state {
        case .parsing:
            return "ellipsis.circle"

        case .pending:
            return "clock"

        case .executing:
            return "arrow.trianglehead.2.clockwise"

        case .completed:
            return "checkmark.circle.fill"

        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    private var statusText: String {
        switch toolExecution.state {
        case .parsing:
            return "Parsing"

        case .pending:
            return "Pending"

        case .executing:
            return "Executing"

        case .completed:
            return "Completed"

        case .failed:
            return "Failed"
        }
    }

    private var hasContent: Bool {
        toolExecution.response != nil
        || toolExecution.errorMessage != nil
        || (toolExecution.sources?.isEmpty == false)
    }

    private var toolDisplayName: String {
        toolExecution.request?.displayName ?? toolExecution.toolName
    }

    // MARK: - Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            toolHeader

            if isExpanded,
                hasContent {
                VStack(alignment: .leading, spacing: Constants.spacing) {
                    if let response = toolExecution.response {
                        toolResultView(response)
                    }

                    if let errorMessage = toolExecution.errorMessage {
                        errorView(errorMessage)
                    }

                    if let sources = toolExecution.sources, !sources.isEmpty {
                        ToolSourcesListView(sources: Array(sources))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Constants.padding)
        .background(backgroundView)
        .overlay(borderOverlay)
        .animation(
            .easeInOut(duration: Constants.animationDuration),
            value: isExpanded
        )
        .animation(
            .easeInOut(duration: Constants.animationDuration),
            value: toolExecution.state
        )
    }

    // MARK: - Subviews

    private var toolHeader: some View {
        HStack(spacing: Constants.headerSpacing) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: Constants.iconSize, weight: .medium))
                .foregroundColor(statusColor)
                .opacity(Constants.iconOpacity)
                .accessibilityHidden(true)

            // Tool name
            Text(toolDisplayName)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.primary)

            // Status text
            Text("·")
                .foregroundColor(.secondary.opacity(Constants.secondaryOpacity))

            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)

            Spacer()

            // Progress or expand indicator
            if toolExecution.state == .executing {
                ProgressView()
                    .scaleEffect(Constants.progressScale)
                    .accessibilityLabel("Executing")
            } else if hasContent {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: Constants.chevronSize, weight: .medium))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if hasContent {
                withAnimation(
                    .spring(
                        response: Constants.animationResponse,
                        dampingFraction: Constants.animationDamping
                    )
                ) {
                    isExpanded.toggle()
                }
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(toolDisplayName), \(statusText)")
        .accessibilityHint(hasContent ? "Tap to \(isExpanded ? "collapse" : "expand") details" : "")
    }

    @ViewBuilder
    private func toolResultView(_ response: ToolResponse) -> some View {
        VStack(alignment: .leading, spacing: Constants.resultSpacing) {
            resultHeader(response: response)
            resultContent(response: response)
        }
        .padding(Constants.resultPadding)
        .background(Color.gray.opacity(Constants.resultBackgroundOpacity))
        .cornerRadius(Constants.resultCornerRadius)
    }

    @ViewBuilder
    private func resultHeader(response: ToolResponse) -> some View {
        HStack {
            Text("Result")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Spacer()

            if !response.result.isEmpty {
                Button {
                    showRawJSON.toggle()
                } label: {
                    Text(showRawJSON ? "Formatted" : "Raw")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func resultContent(response: ToolResponse) -> some View {
        ScrollView {
            if showRawJSON {
                Text(response.result)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            } else {
                Markdown(response.result)
                    .markdownTheme(ThemeCache.shared.getTheme())
                    .markdownCodeSyntaxHighlighter(CodeHighlighter.theme)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxHeight: Constants.resultMaxHeight)
    }

    @ViewBuilder
    private func errorView(_ errorMessage: String) -> some View {
        HStack(spacing: Constants.errorSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
                .accessibilityHidden(true)

            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(Constants.resultPadding)
        .background(Color.red.opacity(Constants.resultBackgroundOpacity))
        .cornerRadius(Constants.resultCornerRadius)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(statusColor.opacity(Constants.backgroundOpacity))
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .stroke(statusColor.opacity(Constants.borderOpacity), lineWidth: Constants.borderWidth)
    }
}
