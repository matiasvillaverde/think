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
        static let pinnedThreshold: CGFloat = 44
        static let bottomAnchorId: String = "chat.messages.bottom.anchor"
        static let bottomAnchorHeight: CGFloat = 1
        static let streamingCompleteBoost: Int = 10_000_000
    }

    @Environment(\.controller)
    private var viewModel: ViewInteractionController
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isPinnedToBottom: Bool = true

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
            messagesScrollView(geometry: geometry)
        }
    }

    private func messagesScrollView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            messagesScrollContent(geometry: geometry, proxy: proxy)
        }
    }

    private func messagesScrollContent(
        geometry: GeometryProxy,
        proxy: ScrollViewProxy
    ) -> some View {
        ScrollView {
            // Used by UI tests; stable identifier for the message list.
            LazyVStack(spacing: UIConstants.messageSpacing) {
                ForEach(messages) { message in
                    MessageView(message: message)
                        .id(message.id)
                        .padding(.bottom, UIConstants.messageBottomPadding)
                }
                loadingIndicator()
                bottomAnchor()
            }
            .padding(.bottom, geometry.size.height - UIConstants.scrollViewBottomOffset)
            .onAppear {
                // Initially scroll to bottom (or top) as needed
                scrollProxy = proxy
                viewModel.scrollToBottom = scrollToLastMessageAnimated
                scrollToLastMessage(proxy: proxy)
            }
            // Avoid jank: `messages.last` changes during streaming updates (SwiftData observation).
            // Only auto-scroll when a *new* message is appended.
            .onChange(of: messages.last?.id) { _, _ in
                scrollToLastMessageAnimated()
            }
            // If we're pinned to the bottom, keep the bottom anchored during streaming updates.
            // This matches ChatGPT behavior: stay pinned unless the user scrolls away.
            .onChange(of: streamingRevision) { _, _ in
                guard isPinnedToBottom else {
                    return
                }
                scrollToBottomAnchor(proxy: proxy)
            }
            .onTapGesture {
                viewModel.removeFocus?()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Dismiss keyboard")
        }
        .accessibilityIdentifier("chat.messages.scroll")
        .coordinateSpace(name: "chat.messages.scrollSpace")
        .onPreferenceChange(BottomAnchorFrameKey.self) { frame in
            guard let frame else {
                return
            }

            let pinned: Bool = frame.maxY <=
                geometry.size.height + UIConstants.pinnedThreshold
            if pinned != isPinnedToBottom {
                isPinnedToBottom = pinned
            }
        }
        #if os(macOS)
            .scrollIndicators(.never)
        #endif
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
        scrollToBottomAnchor(proxy: proxy)
    }

    @MainActor
    private func scrollToLastMessageAnimated() {
        guard let proxy = scrollProxy else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.scrollAnimationDelay) {
            withAnimation(.easeOut(duration: UIConstants.scrollAnimationDuration)) {
                scrollToBottomAnchor(proxy: proxy)
            }
        }
    }

    @MainActor
    private func scrollToBottomAnchor(proxy: ScrollViewProxy) {
        proxy.scrollTo(UIConstants.bottomAnchorId, anchor: .bottom)
    }

    private var streamingRevision: Int {
        guard let lastMessage = messages.last else {
            return 0
        }
        if let channels = lastMessage.channels,
            let final = channels.first(where: { $0.type == .final }) {
            return final.content.count +
                (final.isComplete ? UIConstants.streamingCompleteBoost : 0)
        }
        return (lastMessage.response ?? "").count
    }

    private func bottomAnchor() -> some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: BottomAnchorFrameKey.self,
                    value: geo.frame(in: .named("chat.messages.scrollSpace"))
                )
        }
        .frame(height: UIConstants.bottomAnchorHeight)
        .id(UIConstants.bottomAnchorId)
        .accessibilityIdentifier("chat.messages.bottom")
    }
}

private enum BottomAnchorFrameKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue()
    }
}
