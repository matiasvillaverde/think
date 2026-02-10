import Database
import MarkdownUI
import SwiftUI

// MARK: - UserBubbleView

public struct UserBubbleView: View {
    @Bindable var message: Message
    @Binding var showingSelectionView: Bool
    @Binding var showingStatsView: Bool
    let showAlert: () -> Void
    private let imageScaleFactor: CGFloat = 1

    public var body: some View {
        VStack(alignment: .trailing) {
            userMessageContent
            Spacer()
            fileAttachmentsIfPresent
            userImageIfPresent
        }
        .navigationDestination(isPresented: $showingStatsView) {
            if let metrics = message.metrics {
                DashboardContainer(
                    context: DashboardContext(
                        metric: metrics,
                        chatId: message.chat?.id.uuidString,
                        chatTitle: message.chat?.name,
                        modelName: message.languageModel.name,
                        metrics: [metrics]
                    ),
                    initialType: .singleMetric
                )
                .navigationTitle(Text("Message Metrics", bundle: .module))
                #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
            } else {
                Text("No metrics available for this message", bundle: .module)
                    .padding()
            }
        }
    }

    private var userMessageContent: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: MessageLayout.spacing) {
                userBubbleContent
            }
        }
    }

    private var userBubbleContent: some View {
        Markdown(message.userInput?.convertLaTeX() ?? "")
            .markdownTheme(ThemeCache.shared.getTheme())
            .markdownCodeSyntaxHighlighter(CodeHighlighter.theme)
            .markdownImageProvider(MarkdownImageProvider(scaleFactor: imageScaleFactor))
            .markdownInlineImageProvider(MarkdownInlineImageProvider(scaleFactor: imageScaleFactor))
            .font(.body)
            .foregroundColor(Color.textPrimary)
            .padding(MessageLayout.bubblePadding)
            .background(Color.backgroundPrimary)
            .cornerRadius(MessageLayout.cornerRadius)
            .contextMenu {
                UserContextMenu(
                    textToCopy: message.userInput ?? "",
                    message: message,
                    showingSelectionView: $showingSelectionView,
                    showingStatsView: $showingStatsView
                )
            }
    }

    private var fileAttachmentsIfPresent: some View {
        Group {
            if let files = message.file, !files.isEmpty {
                VStack(spacing: MessageLayout.fileSectionSpacing) {
                    Spacer()
                    ForEach(files) { file in
                        FileAttachmentView(file: file)
                            .frame(width: MessageLayout.fileAttachmentWidth)
                    }
                }
                .padding(.vertical, MessageLayout.verticalPadding)
            }
        }
    }

    private var userImageIfPresent: some View {
        Group {
            if let image = message.userImage {
                ImageView(attachment: image)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var messages: [Message] = Message.allPreviews
        @Previewable @State var isShowing: Bool = false
        List(messages) { message in
            UserBubbleView(
                message: message,
                showingSelectionView: $isShowing,
                showingStatsView: $isShowing,
            ) {
                // no-op
            }
        }
    }
#endif
