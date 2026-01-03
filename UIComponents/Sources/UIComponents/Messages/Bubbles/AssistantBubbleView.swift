import Abstractions
import Database
import LaTeXSwiftUI
import MarkdownUI
import SwiftUI

// MARK: - AssistantBubbleView

public struct AssistantBubbleView: View {
    @Bindable var message: Message
    @Binding var showingSelectionView: Bool
    @Binding var showingThinkingView: Bool
    @Binding var showingStatsView: Bool
    let copyTextAction: (String) -> Void
    let shareTextAction: (String) -> Void

    private let imageScaleFactor: CGFloat = 1
    private let duration: CGFloat = 0.2

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MessageLayout.spacing) {
                contentView
                metricsView
            }
            .sheet(isPresented: $showingSelectionView) {
                SelectionView(
                    text: getFinalContent(),
                    showingSelectionView: $showingSelectionView
                )
            }
            Spacer()
        }
    }

    @ViewBuilder private var contentView: some View {
        VStack {
            ChannelContainerView(
                message: message,
                toolExecutions: getToolExecutions(),
                showingSelectionView: $showingSelectionView,
                showingThinkingView: $showingThinkingView,
                showingStatsView: $showingStatsView,
                copyTextAction: copyTextAction,
                shareTextAction: shareTextAction
            )
            // assistantContentView
        }
    }

    @ViewBuilder private var metricsView: some View {
        if message.metrics != nil {
            HStack {
                if hasToolExecutions {
                    SourcesButton(toolExecutions: getToolExecutionsWithSources())
                }
                AssistantActionButtonsRow(
                    message: message,
                    showingStatsView: $showingStatsView,
                    showingThinkingView: $showingThinkingView,
                    copyTextAction: copyTextAction,
                    shareTextAction: shareTextAction
                )
            }
        }
    }

    private var assistantContentView: some View {
        Markdown(message.response?.convertLaTeX() ?? "")
            .markdownTheme(ThemeCache.shared.getTheme())
            .markdownImageProvider(MarkdownImageProvider(scaleFactor: imageScaleFactor))
            .markdownInlineImageProvider(MarkdownInlineImageProvider(scaleFactor: imageScaleFactor))
            .markdownCodeSyntaxHighlighter(CodeHighlighter.theme)
            .font(.body)
            .foregroundColor(Color.textPrimary)
            .padding(.top, MessageLayout.bubblePadding)
            .background(Color.clear)
            .cornerRadius(MessageLayout.cornerRadius)
            .contextMenu {
                AssistantContextMenu(
                    textToCopy: message.response ?? "",
                    message: message,
                    showingSelectionView: $showingSelectionView,
                    showingThinkingView: $showingThinkingView,
                    showingStatsView: $showingStatsView,
                    copyTextAction: copyTextAction,
                    shareTextAction: shareTextAction
                )
            }
            .animation(
                .easeInOut(duration: duration),
                value: message.response
            )
    }

    private var hasToolExecutions: Bool {
        !getToolExecutions().isEmpty
    }

    private func getToolExecutions() -> [ToolExecution] {
        guard let channels = message.channels else {
            return []
        }
        return channels.compactMap(\.toolExecution)
    }

    private func getToolExecutionsWithSources() -> [ToolExecution] {
        getToolExecutions().filter { execution in
            if let sources = execution.sources {
                return !sources.isEmpty
            }
            return false
        }
    }

    private func getFinalContent() -> String {
        // If we have channels, get the final channel content
        if let channels = message.channels, !channels.isEmpty {
            return channels.first { $0.type == .final }?.content ?? ""
        }
        // Otherwise, fall back to response
        return message.response ?? ""
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var messages: [Message] = Message.allPreviews
        @Previewable @State var isShowing: Bool = false
        ScrollView {
            LazyVStack {
                ForEach(messages) { message in
                    AssistantBubbleView(
                        message: message,
                        showingSelectionView: $isShowing,
                        showingThinkingView: $isShowing,
                        showingStatsView: $isShowing,
                        copyTextAction: { _ in },
                        shareTextAction: { _ in }
                    )
                }
            }
        }
    }
#endif
