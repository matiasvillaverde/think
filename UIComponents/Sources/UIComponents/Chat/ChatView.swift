import Abstractions
import Database
import SwiftData
import SwiftUI

// MARK: - ChatView

public struct ChatView: View {
    // MARK: - Layout Constants

    private enum Layout {
        static let maxContentWidth: CGFloat = 1_000
        static let modelViewMaxHeight: CGFloat = 300
        static let minModelSelectionWidth: CGFloat = 300
        static let minMessagesForReview: Int = 2
    }

    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @Environment(\.controller)
    private var controller: ViewInteractionController

    @Environment(\.reviewPromptViewModel)
    private var reviewPromptViewModel: ReviewPromptManaging

    #if os(macOS)
    @Environment(\.openWindow)
    private var openWindow: OpenWindowAction
    #endif

    // MARK: - State

    @State private var isModelSelectionPopoverPresented: Bool = false
    @State private var isRatingsViewPresented: Bool = false
    @State private var isCanvasPresented: Bool = false
    @State private var isOpenClawSettingsPresented: Bool = false

    @Namespace private var messagesBottomID: Namespace.ID

    // MARK: - Data

    @Query private var messages: [Message]
    @Bindable private var chat: Chat

    // MARK: - Initialization

    public init(chat: Chat) {
        self.chat = chat
        let id: UUID = chat.id
        _messages = Query(
            filter: #Predicate<Message> { $0.chat?.id == id },
            sort: \Message.createdAt
        )
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            contentView
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                ModelSelectionButton(
                    modelText: attributedModelText,
                    isPopoverPresented: $isModelSelectionPopoverPresented,
                    chat: chat
                )
            }

            ToolbarItem(placement: .automatic) {
                NewChatButton(chat: chat)
            }

            ToolbarItem(placement: .automatic) {
                analyticsButton
            }

            ToolbarItem(placement: .automatic) {
                canvasButton
            }

            ToolbarItem(placement: .automatic) {
                OpenClawStatusButton(isSettingsPresented: $isOpenClawSettingsPresented)
            }
        }
        .frame(maxWidth: Layout.maxContentWidth)
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.backgroundSecondary)
        #endif
            .onChange(of: isModelSelectionPopoverPresented) { _, _ in
                controller.removeFocus?()
            }
            .onChange(of: messages) { _, newValue in
                if newValue.count > Layout.minMessagesForReview {
                    // It is a good action
                    Task(priority: .utility) {
                        await reviewPromptViewModel.recordPositiveAction()

                        if reviewPromptViewModel.shouldAskForReview {
                            // Set the state to true to trigger the sheet presentation
                            await MainActor.run {
                                isRatingsViewPresented = true
                            }
                        }
                    }
                }
            }
            .overlay {
                if isRatingsViewPresented {
                    RatingsView(isRatingsViewPresented: $isRatingsViewPresented)
                        .transition(.opacity)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: isRatingsViewPresented)
                }
            }
            .sheet(isPresented: $isCanvasPresented) {
                CanvasView(chat: chat)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .sheet(isPresented: $isOpenClawSettingsPresented) {
                OpenClawSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }

    // MARK: - Content Views

    @ViewBuilder private var contentView: some View {
        if isModelDownloading {
            ModelDownloadingView(chat: chat)
        } else {
            ChatContentView(
                chat: chat,
                messageCount: messages.count
            )
        }
    }

    private var isModelDownloading: Bool {
        if chat.languageModel.state?.isDownloading == true {
            return true
        }
        if chat.imageModel.state?.isDownloading == true {
            return true
        }
        return false
    }

    // MARK: - Properties

    private var shouldShowPrompts: Bool {
        messages.count == 1 && chat.languageModel.runtimeState == .loaded
    }

    private var attributedModelText: AttributedString {
        var title: AttributedString = AttributedString("Think")
        title.font = .headline.bold()
        title.foregroundColor = Color.marketingPrimary
        return title
    }

    @ViewBuilder private var analyticsButton: some View {
        #if os(macOS)
            Button {
                openWindow(id: "analytics")
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .accessibilityLabel("View Chat Metrics")
            }
            .help("View Chat Metrics")
        #else
            NavigationLink {
                DashboardContainer(
                    context: DashboardContext(
                        metric: messages.last?.metrics,
                        chatId: chat.id.uuidString,
                        chatTitle: chat.name,
                        modelName: chat.languageModel.name,
                        metrics: messages.compactMap(\.metrics)
                    ),
                    initialType: .chatMetrics
                )
                .navigationTitle("Analytics Dashboard")
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .accessibilityLabel("View Chat Metrics")
            }
        #endif
    }

    private var canvasButton: some View {
        Button {
            isCanvasPresented = true
        } label: {
            Image(systemName: "square.and.pencil")
                .accessibilityLabel("Open Canvas")
        }
        .help("Open Canvas")
    }
}

// MARK: - Preview

#if DEBUG
    #Preview(traits: .modifier(PreviewDatabase())) {
        @Previewable @State var chat: Chat = Chat.preview
        ChatView(chat: chat)
    }
#endif
