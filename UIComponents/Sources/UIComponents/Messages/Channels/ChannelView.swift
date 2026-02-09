import Abstractions
import Database
import LaTeXSwiftUI
import MarkdownUI
import SwiftUI

/// A view that displays a single channel entity
internal struct ChannelView: View {
    // MARK: - Constants

    private enum Constants {
        static let animationDuration: Double = 0.3
        static let streamingAnimationDuration: Double = 1.0
        static let streamingOpacity: Double = 0.7
        static let fullOpacity: Double = 1.0
        static let cornerRadius: CGFloat = 12
        static let spacing: CGFloat = 8
        static let padding: CGFloat = 16
        static let indicatorScale: CGFloat = 0.7
        static let dotSize: CGFloat = 4
        static let dotSpacing: CGFloat = 4
        static let dotAnimationDuration: Double = 0.6
        static let dotAnimationDelay: Double = 0.2
        static let dotScaleMin: CGFloat = 0.5
        static let borderOpacity: Double = 0.2
        static let borderWidth: CGFloat = 1
        static let dotOpacity: Double = 0.6
        static let headerSpacing: CGFloat = 6
        static let dotCount: Int = 3
        static let previewHeight: CGFloat = 400
    }

    // MARK: - Properties

    @Bindable var channel: Channel
    @State private var isAnimating: Bool = false

    // MARK: - Computed Properties

    internal var showsStreamingIndicator: Bool {
        !channel.isComplete
    }

    internal var shouldHide: Bool {
        channel.content.isEmpty
    }

    private var typeColor: Color {
        switch channel.type {
        case .analysis:
            return .gray

        case .commentary:
            return .orange

        case .final:
            return .primary

        case .tool:
            return .orange
        }
    }

    private var typeIcon: String {
        switch channel.type {
        case .analysis:
            return "brain"

        case .commentary:
            return "bubble.left.and.bubble.right"

        case .final:
            return "checkmark.circle"

        case .tool:
            return "wrench.and.screwdriver"
        }
    }

    // MARK: - Initialization

    internal init(channel: Channel) {
        self.channel = channel
    }

    // MARK: - Body

    internal var body: some View {
        if !shouldHide {
            contentView
                .animation(
                    .easeInOut(duration: Constants.animationDuration),
                    value: channel.content
                )
                .onAppear {
                    if showsStreamingIndicator {
                        withAnimation(
                            .easeInOut(duration: Constants.streamingAnimationDuration)
                                .repeatForever(autoreverses: true)
                        ) {
                            isAnimating = true
                        }
                    }
                }
        }
    }

    @ViewBuilder private var contentView: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            // Header with type indicator
            headerView

            // Content with Markdown rendering
            Markdown(channel.content.convertLaTeX())
                .markdownTheme(ThemeCache.shared.getTheme())
                .markdownImageProvider(
                    MarkdownImageProvider(scaleFactor: Constants.fullOpacity)
                )
                .markdownInlineImageProvider(
                    MarkdownInlineImageProvider(scaleFactor: Constants.fullOpacity)
                )
                .markdownCodeSyntaxHighlighter(CodeHighlighter.theme)
                .font(.body)
                .foregroundColor(typeColor.opacity(Constants.fullOpacity))
                .opacity(
                    showsStreamingIndicator ?
                    Constants.streamingOpacity :
                    Constants.fullOpacity
                )
                .animation(
                    .easeInOut(duration: Constants.animationDuration),
                    value: channel.content
                )

            // Streaming indicator
            if showsStreamingIndicator {
                streamingIndicator
            }
        }
        .padding()
        .background(backgroundView)
        .cornerRadius(Constants.cornerRadius)
    }

    private var headerView: some View {
        HStack(spacing: Constants.headerSpacing) {
            Image(systemName: typeIcon)
                .font(.caption)
                .foregroundColor(typeColor)
                .accessibilityLabel(channelTypeLabel)

            Text(channelTypeLabel)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(typeColor)

            if let recipient = channel.recipient {
                Text("→ \(recipient)")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
            }

            Spacer()

            if showsStreamingIndicator {
                ProgressView()
                    .scaleEffect(Constants.indicatorScale)
            }
        }
    }

    private var streamingIndicator: some View {
        HStack(spacing: Constants.dotSpacing) {
            ForEach(0..<Constants.dotCount, id: \.self) { index in
                Circle()
                    .fill(typeColor.opacity(Constants.dotOpacity))
                    .frame(width: Constants.dotSize, height: Constants.dotSize)
                    .scaleEffect(isAnimating ? Constants.fullOpacity : Constants.dotScaleMin)
                    .animation(
                        .easeInOut(duration: Constants.dotAnimationDuration)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * Constants.dotAnimationDelay),
                        value: isAnimating
                    )
            }
        }
        .padding(.top, Constants.dotSpacing)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(Color.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(
                        typeColor.opacity(Constants.borderOpacity),
                        lineWidth: Constants.borderWidth
                    )
            )
    }

    private var channelTypeLabel: String {
        switch channel.type {
        case .analysis:
            return "Thinking"

        case .commentary:
            return "Commentary"

        case .final:
            return "Response"

        case .tool:
            return "Tool"
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Final Channel") {
        ChannelView(channel: Channel(
            type: .final,
            content: "This is a final response with **markdown** support and `code`.",
            order: 0,
            isComplete: true
        ))
        .padding()
    }

    #Preview("Analysis Channel - Streaming") {
        ChannelView(channel: Channel(
            type: .analysis,
            content: "Let me analyze this problem step by step...",
            order: 0,
            isComplete: false
        ))
        .padding()
    }

    #Preview("Commentary Channel") {
        ChannelView(channel: Channel(
            type: .commentary,
            content: "Here's an interesting observation about the data.",
            order: 0,
            recipient: "user",
            isComplete: true
        ))
        .padding()
    }

    #Preview("Tool Channel - Executing") {
        ChannelView(channel: Channel(
            type: .tool,
            content: "Executing calculation: 42 * 3.14159",
            order: 0,
            toolExecution: ToolExecution(
                request: ToolRequest(
                    name: "calculator",
                    arguments: "{\"expression\": \"42 * 3.14159\"}",
                    displayName: "Calculator"
                ),
                state: .executing
            ),
            isComplete: false
        ))
        .padding()
    }
#endif
