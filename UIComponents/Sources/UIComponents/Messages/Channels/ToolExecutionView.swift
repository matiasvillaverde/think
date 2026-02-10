import Abstractions
import Database
import Foundation
import MarkdownUI
import SwiftUI

internal enum ToolExecutionViewConstants {
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
    static let statusLineLimit: Int = 2
    static let requestMaxHeightDivisor: CGFloat = 2
}

/// Enhanced tool execution view with expandable results and source display
internal struct ToolExecutionView: View {
    // MARK: - Constants

    // MARK: - Properties

    @Bindable var toolExecution: ToolExecution
    @Environment(\.controller)
    var controller: ViewInteractionController
    @State private var isExpanded: Bool = false
    @State private var showRawJSON: Bool = false

    // MARK: - Computed Properties

    var statusColor: Color {
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

    var statusIcon: String {
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

    var statusText: String {
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

    var hasContent: Bool {
        toolExecution.request != nil
        || !toolExecution.requestJSON.isEmpty
        || toolExecution.response != nil
        || toolExecution.errorMessage != nil
        || (toolExecution.sources?.isEmpty == false)
    }

    var toolDisplayName: String {
        toolExecution.request?.displayName ?? toolExecution.toolName
    }

    var isExpandedValue: Bool {
        isExpanded
    }

    private var requestArgumentsText: String {
        ToolExecutionViewHelpers.requestArgumentsText(toolExecution)
    }

    private var statusMessage: String {
        toolExecution.statusMessage ?? ""
    }

    private var shouldShowStatusMessage: Bool {
        toolExecution.state == .executing && toolExecution.statusMessage?.isEmpty == false
    }

    // MARK: - Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: ToolExecutionViewConstants.spacing) {
            toolHeader

            if shouldShowStatusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(ToolExecutionViewConstants.statusLineLimit)
            }

            if isExpanded,
                hasContent {
                VStack(alignment: .leading, spacing: ToolExecutionViewConstants.spacing) {
                    if !requestArgumentsText.isEmpty {
                        toolRequestView(requestArgumentsText)
                    }

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
        .padding(ToolExecutionViewConstants.padding)
        .background(backgroundView)
        .overlay(borderOverlay)
        .animation(
            .easeInOut(duration: ToolExecutionViewConstants.animationDuration),
            value: isExpanded
        )
        .animation(
            .easeInOut(duration: ToolExecutionViewConstants.animationDuration),
            value: toolExecution.state
        )
    }

    // MARK: - Subviews

    @ViewBuilder
    private func toolRequestView(_ argumentsText: String) -> some View {
        VStack(alignment: .leading, spacing: ToolExecutionViewConstants.resultSpacing) {
            HStack {
                Text("Request", bundle: .module)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.textSecondary)
                Spacer()
            }

            ScrollView {
                Text(argumentsText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color.textPrimary)
                    .textSelection(.enabled)
            }
            .frame(
                maxHeight: ToolExecutionViewConstants.resultMaxHeight
                    / ToolExecutionViewConstants.requestMaxHeightDivisor
            )
        }
        .padding(ToolExecutionViewConstants.resultPadding)
        .background(Color.paletteGray.opacity(ToolExecutionViewConstants.resultBackgroundOpacity))
        .cornerRadius(ToolExecutionViewConstants.resultCornerRadius)
        // Collapse this block into a single accessible element so UI tests can reliably query it
        // and VoiceOver users get a meaningful summary.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Request", bundle: .module))
        .accessibilityValue(argumentsText)
        .accessibilityIdentifier("toolExecution.request.\(toolExecution.id.uuidString)")
    }

    @ViewBuilder
    private func toolResultView(_ response: ToolResponse) -> some View {
        VStack(alignment: .leading, spacing: ToolExecutionViewConstants.resultSpacing) {
            resultHeader(response: response)
            resultContent(response: response)
        }
        .padding(ToolExecutionViewConstants.resultPadding)
        .background(Color.paletteGray.opacity(ToolExecutionViewConstants.resultBackgroundOpacity))
        .cornerRadius(ToolExecutionViewConstants.resultCornerRadius)
        // Ensure nested controls (e.g. Raw/Formatted toggle) remain individually accessible
        // for UI testing.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toolExecution.result.\(toolExecution.id.uuidString)")
    }

    @ViewBuilder
    private func resultHeader(response: ToolResponse) -> some View {
        HStack {
            Text("Result", bundle: .module)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color.textSecondary)

            Spacer()

            if !response.result.isEmpty {
                Button {
                    showRawJSON.toggle()
                } label: {
                    Text(
                        showRawJSON
                            ? String(localized: "Formatted", bundle: .module)
                            : String(localized: "Raw", bundle: .module)
                    )
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("toolExecution.rawToggle.\(toolExecution.id.uuidString)")
            }
        }
    }

    @ViewBuilder
    private func resultContent(response: ToolResponse) -> some View {
        ScrollView {
            if showRawJSON {
                Text(response.result)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color.textPrimary)
                    .textSelection(.enabled)
            } else {
                Markdown(response.result)
                    .markdownTheme(ThemeCache.shared.getTheme())
                    .markdownCodeSyntaxHighlighter(CodeHighlighter.theme)
                    .font(.caption)
                    .foregroundColor(Color.textPrimary)
            }
        }
        .frame(maxHeight: ToolExecutionViewConstants.resultMaxHeight)
    }

    @ViewBuilder
    private func errorView(_ errorMessage: String) -> some View {
        HStack(spacing: ToolExecutionViewConstants.errorSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
                .accessibilityHidden(true)

            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(ToolExecutionViewConstants.resultPadding)
        .background(Color.paletteRed.opacity(ToolExecutionViewConstants.resultBackgroundOpacity))
        .cornerRadius(ToolExecutionViewConstants.resultCornerRadius)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: ToolExecutionViewConstants.cornerRadius)
            .fill(statusColor.opacity(ToolExecutionViewConstants.backgroundOpacity))
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: ToolExecutionViewConstants.cornerRadius)
            .stroke(
                statusColor.opacity(ToolExecutionViewConstants.borderOpacity),
                lineWidth: ToolExecutionViewConstants.borderWidth
            )
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }
}

private enum ToolExecutionViewHelpers {
    static func requestArgumentsText(_ toolExecution: ToolExecution) -> String {
        if let request = toolExecution.request {
            return request.arguments
        }

        guard let data = toolExecution.requestJSON.data(using: .utf8) else {
            return toolExecution.requestJSON
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return toolExecution.requestJSON
        }
        if let arguments = object["arguments"] as? String {
            return arguments
        }
        return toolExecution.requestJSON
    }
}
