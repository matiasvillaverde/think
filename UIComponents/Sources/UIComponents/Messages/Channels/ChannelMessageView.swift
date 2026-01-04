import Abstractions
import Database
import LaTeXSwiftUI
import MarkdownUI
import OSLog
import SwiftUI

/// A view that renders a single channel message based on its type
internal struct ChannelMessageView: View, @preconcurrency Equatable {
    private static let kLogger: Logger = Logger(
        subsystem: "UIComponents",
        category: "ChannelMessageView"
    )

    // MARK: - Constants

    internal enum Constants {
        static let channelSpacing: CGFloat = 4
        static let headerSpacing: CGFloat = 8
        static let cornerRadius: CGFloat = 8
        static let animationDuration: Double = 0.2
        static let analysisOpacity: Double = 0.5
        static let commentaryOpacity: Double = 1.0
        static let commentaryColorOpacity: Double = 0.8
        static let analysisFontSize: CGFloat = 11
        static let contentPadding: CGFloat = 12
        static let uuidPrefixLength: Int = 8
        static let borderWidth: CGFloat = 1
        static let borderOpacity: Double = 0.15
        static let backgroundOpacity: Double = 0.02
    }

    @Bindable var message: Message
    @Bindable var channel: Channel

    let associatedToolStatus: ToolExecutionState?
    @State private var isCollapsed: Bool = false
    private let imageScaleFactor: CGFloat = 1

    private var computedChannelTitle: String {
        switch channel.type {
        case .analysis:
            return String(localized: "Thinking", bundle: .module)

        case .commentary:
            return String(localized: "Working", bundle: .module)

        case .final:
            return String(localized: "Response", bundle: .module)

        case .tool:
            return String(localized: "Tool", bundle: .module)
        }
    }

    // Optional properties for context menu support
    @Binding var showingSelectionView: Bool
    @Binding var showingThinkingView: Bool
    @Binding var showingStatsView: Bool
    let copyTextAction: ((String) -> Void)?
    let shareTextAction: ((String) -> Void)?

    internal init(
        channel: Channel,
        message: Message,
        associatedToolStatus: ToolExecutionState? = nil,
        showingSelectionView: Binding<Bool> = .constant(false),
        showingThinkingView: Binding<Bool> = .constant(false),
        showingStatsView: Binding<Bool> = .constant(false),
        copyTextAction: ((String) -> Void)? = nil,
        shareTextAction: ((String) -> Void)? = nil
    ) {
        self.channel = channel
        self.associatedToolStatus = associatedToolStatus
        self.message = message
        self._showingSelectionView = showingSelectionView
        self._showingThinkingView = showingThinkingView
        self._showingStatsView = showingStatsView
        self.copyTextAction = copyTextAction
        self.shareTextAction = shareTextAction
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: Constants.channelSpacing) {
            if channel.type == .analysis || channel.type == .commentary {
                channelHeader
            }

            if !isCollapsed {
                channelContent
            }
        }
    }

    @ViewBuilder private var channelHeader: some View {
        HStack(spacing: Constants.headerSpacing) {
            channelIcon
                .accessibilityHidden(true)
                .modifier(
                    PulsingAnimationModifier(
                        isActive: channel.type == .analysis && !isCollapsed
                    )
                )
            Text(computedChannelTitle)
                .font(.caption)
                .foregroundColor(channelColor)
            if channel.type == .commentary,
                associatedToolStatus == .executing {
                LoadingDotsView()
            }
            Spacer()
            if channel.type == .analysis {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if channel.type == .analysis {
                withAnimation(.easeInOut(duration: Constants.animationDuration)) {
                    isCollapsed.toggle()
                }
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            channel.type == .analysis
            ? String(localized: "Toggle thinking content", bundle: .module)
            : computedChannelTitle
        )
    }

    @ViewBuilder private var channelContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch channel.type {
            case .final:
                finalChannelContent

            case .analysis:
                analysisChannelContent

            case .commentary:
                commentaryChannelContent

            case .tool:
                toolChannelContent
            }
        }
    }

    @ViewBuilder private var finalChannelContent: some View {
        Markdown(channel.content.convertLaTeX())
            .markdownTheme(ThemeCache.shared.getTheme())
            .markdownImageProvider(MarkdownImageProvider(scaleFactor: imageScaleFactor))
            .markdownInlineImageProvider(
                MarkdownInlineImageProvider(scaleFactor: imageScaleFactor)
            )
            .markdownCodeSyntaxHighlighter(CodeHighlighter.theme)
            .font(.body)
            .foregroundColor(Color.textPrimary)
            .padding(Constants.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .overlay(borderOverlay)
            .contextMenu {
                if  let copyAction = copyTextAction,
                    let shareAction = shareTextAction {
                    AssistantContextMenu(
                        textToCopy: channel.content,
                        message: message,
                        showingSelectionView: $showingSelectionView,
                        showingThinkingView: $showingThinkingView,
                        showingStatsView: $showingStatsView,
                        copyTextAction: copyAction,
                        shareTextAction: shareAction
                    )
                }
            }
    }

    @ViewBuilder private var analysisChannelContent: some View {
        Text(channel.content)
            .font(.system(
                size: Constants.analysisFontSize,
                weight: .medium,
                design: .monospaced
            ))
            .foregroundColor(.textSecondary)
            .padding(Constants.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .overlay(borderOverlay)
    }

    @ViewBuilder private var commentaryChannelContent: some View {
        Markdown(channel.content)
            .markdownTheme(ThemeCache.shared.getTheme())
            .font(.body)
            .foregroundColor(Color.textPrimary)
            .padding(Constants.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .overlay(borderOverlay)
    }

    @ViewBuilder private var toolChannelContent: some View {
        Text(channel.content)
            .font(.caption)
            .foregroundColor(.orange)
            .padding(Constants.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .overlay(borderOverlay)
    }

    // MARK: - Helper Views

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(channelBackgroundColor)
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .stroke(channelBorderColor, lineWidth: Constants.borderWidth)
    }

    private var channelBackgroundColor: Color {
        switch channel.type {
        case .final:
            return Color.gray.opacity(Constants.backgroundOpacity)

        case .analysis:
            return Color.blue.opacity(Constants.backgroundOpacity)

        case .commentary:
            return Color.orange.opacity(Constants.backgroundOpacity)

        case .tool:
            return Color.purple.opacity(Constants.backgroundOpacity)
        }
    }

    private var channelBorderColor: Color {
        switch channel.type {
        case .final:
            return Color.gray.opacity(Constants.borderOpacity)

        case .analysis:
            return Color.blue.opacity(Constants.borderOpacity)

        case .commentary:
            return Color.orange.opacity(Constants.borderOpacity)

        case .tool:
            return Color.purple.opacity(Constants.borderOpacity)
        }
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.channel.id == rhs.channel.id &&
        lhs.channel.content == rhs.channel.content &&
        lhs.channel.isComplete == rhs.channel.isComplete &&
        lhs.channel.lastUpdated == rhs.channel.lastUpdated
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Final Response") {
        @Previewable @State var channel: Channel = Channel(
            type: .final,
            content: """
                Here's the solution to your problem:

                ```swift
                func calculate() -> Int {
                    return 42
                }
                ```
                """,
            order: 0,
            isComplete: true
        )
        @Previewable @State var message: Message = Message.previewWithResponse
        @Previewable @State var showingSelection: Bool = false
        @Previewable @State var showingThinking: Bool = false
        @Previewable @State var showingStats: Bool = false

        ChannelMessageView(
            channel: channel,
            message: message,
            showingSelectionView: $showingSelection,
            showingThinkingView: $showingThinking,
            showingStatsView: $showingStats,
            copyTextAction: { _ in
                // no-op
            },
            shareTextAction: { _ in
                // no-op
            }
        )
        .padding()
    }

    #Preview("Analysis Thinking") {
        @Previewable @State var channel: Channel = Channel(
            type: .analysis,
            content: """
                Analyzing the request... This involves multiple steps to solve the problem.
                """,
            order: 0,
            isComplete: false
        )
        @Previewable @State var message: Message = Message.previewWithThinking

        ChannelMessageView(
            channel: channel,
            message: message
        )
        .padding()
    }

    #Preview("Commentary with Tool") {
        @Previewable @State var channel: Channel = Channel(
            type: .commentary,
            content: "Running calculation to determine the result...",
            order: 0,
            isComplete: false
        )
        @Previewable @State var message: Message = Message.previewWithResponse

        ChannelMessageView(
            channel: channel,
            message: message,
            associatedToolStatus: .executing
        )
        .padding()
    }
#endif
