import Abstractions
import Database
import LaTeXSwiftUI
import MarkdownUI
import OSLog
import SwiftUI

/// A view that renders a single channel message based on its type
internal struct ChannelMessageView: View {
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
    @Binding var showingStatsView: Bool
    let copyTextAction: ((String) -> Void)?
    let shareTextAction: ((String) -> Void)?

    internal init(
        channel: Channel,
        message: Message,
        associatedToolStatus: ToolExecutionState? = nil,
        showingSelectionView: Binding<Bool> = .constant(false),
        showingStatsView: Binding<Bool> = .constant(false),
        copyTextAction: ((String) -> Void)? = nil,
        shareTextAction: ((String) -> Void)? = nil
    ) {
        self.channel = channel
        self.associatedToolStatus = associatedToolStatus
        self.message = message
        self._showingSelectionView = showingSelectionView
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("channel.\(channel.type.rawValue).container")
    }

    @ViewBuilder private var channelHeader: some View {
        Button {
            guard channel.type == .analysis else {
                return
            }
            withAnimation(.easeInOut(duration: Constants.animationDuration)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: Constants.headerSpacing) {
                channelIcon
                    .accessibilityHidden(true)
                    .modifier(
                        PulsingAnimationModifier(
                            isActive: channel.type == .analysis
                                && !isCollapsed
                                && !channel.isComplete
                        )
                    )
                Text(computedChannelTitle)
                    .font(.caption)
                    .foregroundColor(channelColor)
                if channel.type == .commentary, associatedToolStatus == .executing {
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
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            channel.type == .analysis
                ? String(localized: "Toggle thinking content", bundle: .module)
                : computedChannelTitle
        )
        // Make headers reliably targetable when multiple channels of the same type exist.
        .accessibilityIdentifier("channel.\(channel.type.rawValue).header.\(channel.id.uuidString)")
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
        Group {
            if channel.isComplete {
                Markdown(channel.content.convertLaTeX())
                    .markdownTheme(ThemeCache.shared.getTheme())
                    .markdownImageProvider(MarkdownImageProvider(scaleFactor: imageScaleFactor))
                    .markdownInlineImageProvider(
                        MarkdownInlineImageProvider(scaleFactor: imageScaleFactor)
                    )
                    .markdownCodeSyntaxHighlighter(CodeHighlighter.theme)
            } else {
                // Markdown parsing during streaming is expensive and causes jank.
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(channel.content)
                        .font(.body)
                    StreamingCursorView()
                        .padding(.leading, 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .foregroundColor(Color.textPrimary)
        .padding(Constants.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundView)
        .overlay(borderOverlay)
        // Make this reliably queryable in XCUITests (MarkdownUI renders multiple nested views).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(channel.content)
        .accessibilityIdentifier("channel.final.content")
        .contextMenu {
            if let copyAction = copyTextAction, let shareAction = shareTextAction {
                AssistantContextMenu(
                    textToCopy: channel.content,
                    message: message,
                    showingSelectionView: $showingSelectionView,
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
            .accessibilityIdentifier("channel.analysis.content.\(channel.id.uuidString)")
    }

    @ViewBuilder private var commentaryChannelContent: some View {
        Group {
            if channel.isComplete {
                Markdown(channel.content)
                    .markdownTheme(ThemeCache.shared.getTheme())
            } else {
                Text(channel.content)
                    .font(.body)
            }
        }
        .foregroundColor(Color.textPrimary)
        .padding(Constants.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundView)
        .overlay(borderOverlay)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(channel.content)
        .accessibilityIdentifier("channel.commentary.content")
    }

    @ViewBuilder private var toolChannelContent: some View {
        Text(channel.content)
            .font(.caption)
            .foregroundColor(.orange)
            .padding(Constants.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .overlay(borderOverlay)
            .accessibilityIdentifier("channel.tool.content")
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
            return Color.paletteGray.opacity(Constants.backgroundOpacity)

        case .analysis:
            return Color.paletteBlue.opacity(Constants.backgroundOpacity)

        case .commentary:
            return Color.paletteOrange.opacity(Constants.backgroundOpacity)

        case .tool:
            return Color.palettePurple.opacity(Constants.backgroundOpacity)
        }
    }

    private var channelBorderColor: Color {
        switch channel.type {
        case .final:
            return Color.paletteGray.opacity(Constants.borderOpacity)

        case .analysis:
            return Color.paletteBlue.opacity(Constants.borderOpacity)

        case .commentary:
            return Color.paletteOrange.opacity(Constants.borderOpacity)

        case .tool:
            return Color.palettePurple.opacity(Constants.borderOpacity)
        }
    }
}

/// Lightweight "streaming cursor" to communicate that text is still being produced,
/// without animating the entire text layout on every delta.
private struct StreamingCursorView: View {
    private enum Constants {
        static let blinkInterval: TimeInterval = 0.55
        static let onOpacity: Double = 0.9
        static let offOpacity: Double = 0.15
        static let glyph: String = "▍"
        static let phaseModulo: Int = 2
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: Constants.blinkInterval)) { context in
            let timeInterval: TimeInterval = context.date.timeIntervalSinceReferenceDate
            let phaseIndex: Int = Int(timeInterval / Constants.blinkInterval)
            let isOn: Bool = (phaseIndex % Constants.phaseModulo) == 0

            Text(Constants.glyph)
                .font(.body)
                .opacity(isOn ? Constants.onOpacity : Constants.offOpacity)
                .foregroundColor(.textSecondary)
        }
    }
}
