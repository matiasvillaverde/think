import Database
import SwiftData
import SwiftUI

public struct MessagesView: View {
    // MARK: - UI Constants

    private enum UIConstants {
        static let messageSpacing: CGFloat = 16
        static let messageBottomPadding: CGFloat = 5
        static let scrollViewBottomOffset: CGFloat = 100
        static let scrollAnimationDelay: TimeInterval = 0.5
        static let scrollOffsetX: CGFloat = 0.5
        static let scrollOffsetY: CGFloat = 1.2
        static let scrollAnimationDuration: TimeInterval = 0.3
    }

    @Environment(\.controller)
    private var viewModel: ViewInteractionController
    @State private var scrollProxy: ScrollViewProxy?

    @Query private var messages: [Message]

    @Bindable private var chat: Chat

    init(chat: Chat) {
        self.chat = chat
        let id: UUID = chat.id
        _messages = Query(
            filter: #Predicate<Message> { $0.chat?.id == id },
            sort: \Message.createdAt,
            animation: .easeInOut
        )
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    // Used by UI tests; stable identifier for the message list.
                    LazyVStack(spacing: UIConstants.messageSpacing) {
                        ForEach(messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .padding(.bottom, UIConstants.messageBottomPadding)
                        }
                        loadingIndicator()
                    }
                    .padding(.bottom, geometry.size.height - UIConstants.scrollViewBottomOffset)
                    .onAppear {
                        // Initially scroll to bottom (or top) as needed
                        scrollProxy = proxy
                        viewModel.scrollToBottom = scrollToLastMessageAnimated
                        scrollToLastMessage(proxy: proxy)
                    }
                    // Avoid jank: `messages.last` changes during streaming updates.
                    // (SwiftData observation)
                    // Only auto-scroll when a *new* message is appended.
                    .onChange(of: messages.last?.id) { _, _ in
                        scrollToLastMessageAnimated()
                    }
                    .onTapGesture {
                        viewModel.removeFocus?()
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Dismiss keyboard")
                }
                .accessibilityIdentifier("chat.messages.scroll")
                #if os(macOS)
                    .scrollIndicators(.never)
                #endif
            }
        }
    }

    // MARK: - Loading indicator

    @ViewBuilder
    private func loadingIndicator() -> some View {
        if let lastMessage = messages.last {
            // Show generic loading indicator if message has input but no response yet
            if
                lastMessage.channels?.isEmpty ?? true,
                lastMessage.responseImage == nil,
                lastMessage.userInput != nil ||
                lastMessage.file != nil ||
                lastMessage.userImage != nil {
                withAnimation(.easeInOut) {
                    HStack {
                        LoadingCircleView()
                            .padding(.leading)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Scroll Handling

    /// Scrolls so that the bottom anchor is at the bottom of the screen
    @MainActor
    private func scrollToLastMessage(proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else {
            return
        }
        proxy.scrollTo(lastMessage.id, anchor: .top)
    }

    @MainActor
    private func scrollToLastMessageAnimated() {
        guard let lastMessage = messages.last, let proxy = scrollProxy else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.scrollAnimationDelay) {
            withAnimation(.easeOut(duration: UIConstants.scrollAnimationDuration)) {
                proxy.scrollTo(
                    lastMessage.id,
                    anchor: .top
                )
            }
        }
    }
}
