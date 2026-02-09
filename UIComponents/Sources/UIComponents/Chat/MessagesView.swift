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
            static let uiTestBottomAnchorHeight: CGFloat = 44
            static let uiTestHittableOpacity: Double = 0.01
            static let streamingCompleteBoost: Int = 10_000_000
        }

    @Environment(\.controller)
    private var viewModel: ViewInteractionController
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isPinnedToBottom: Bool = true
    @State private var isAutoScrollSuppressed: Bool = false
    private let isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--ui-testing")

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
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                messagesScrollView(geometry: geometry)
            }

            if isUITesting {
                pinnedProbeView
            }
        }
    }

    private var pinnedProbeView: some View {
        let label: String = isPinnedToBottom ? "pinned=true" : "pinned=false"
        return Text(label)
            .font(.system(size: 1))
            .padding(1)
            // Slight visibility ensures XCUITest will surface it in the accessibility tree.
            .background(Color.paletteBlack.opacity(UIConstants.uiTestHittableOpacity))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityIdentifier("uiTest.pinnedProbe")
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
        configuredScrollView(
            ScrollView {
                scrollBody(geometry: geometry, proxy: proxy)
            },
            geometry: geometry
        )
    }

    private func scrollBody(
        geometry: GeometryProxy,
        proxy: ScrollViewProxy
    ) -> some View {
        // Keep messages lazy, but make the bottom anchor non-lazy so it always exists in the
        // view hierarchy (UI tests rely on it being discoverable).
        VStack(spacing: 0) {
            LazyVStack(spacing: UIConstants.messageSpacing) {
                ForEach(messages) { message in
                    MessageView(message: message)
                        .id(message.id)
                        .padding(.bottom, UIConstants.messageBottomPadding)
                }
                loadingIndicator()
            }
            bottomAnchor()
        }
        // The large bottom padding improves usability in the real app (keeps the last message
        // above the composer), but it makes deterministic UI testing harder by pushing the
        // bottom sentinel out of view. Disable it under `--ui-testing`.
        .padding(
            .bottom,
            isUITesting ? 0 : (geometry.size.height - UIConstants.scrollViewBottomOffset)
        )
        .onAppear {
            // Initially scroll to bottom (or top) as needed
            scrollProxy = proxy
            viewModel.scrollToBottom = {
                isAutoScrollSuppressed = false
                scrollToLastMessageAnimated()
            }
            viewModel.suppressAutoScroll = {
                isAutoScrollSuppressed = true
            }
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
            guard isPinnedToBottom, !isAutoScrollSuppressed else {
                return
            }
            scrollToBottomAnchor(proxy: proxy)
        }
        .onTapGesture {
            viewModel.removeFocus?()
        }
        // Keep the gesture discoverable for assistive tech (SwiftLint rule),
        // but avoid overriding the scroll view's children semantics.
        .accessibilityAddTraits(.isButton)
    }

    private func configuredScrollView<V: View>(
        _ scrollView: V,
        geometry: GeometryProxy
    ) -> some View {
        scrollView
            // UI tests need to query and swipe the actual scroll view.
            .accessibilityIdentifier("chat.messages.scroll")
            .accessibilityElement(children: .contain)
            .coordinateSpace(name: "chat.messages.scrollSpace")
            .onPreferenceChange(BottomAnchorFrameKey.self) { frame in
                updatePinnedState(from: frame, geometry: geometry)
            }
            #if os(macOS)
                .scrollIndicators(.never)
            #endif
    }

    private func updatePinnedState(from frame: CGRect?, geometry: GeometryProxy) {
        guard let frame else {
            return
        }

        let pinned: Bool = frame.maxY <= geometry.size.height + UIConstants.pinnedThreshold
        if pinned != isPinnedToBottom {
            isPinnedToBottom = pinned
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
        let height: CGFloat = isUITesting
            ? UIConstants.uiTestBottomAnchorHeight
            : UIConstants.bottomAnchorHeight

            return ZStack {
                if isUITesting {
                    // XCUITest struggles to consider fully transparent/non-interactive elements
                    // "hittable". This is a no-op sentinel we can query and drag against.
                    Button(action: {
                        // No-op: this button exists only as a deterministic UI-test sentinel.
                    }, label: {
                        Rectangle()
                            .fill(Color.paletteBlack.opacity(UIConstants.uiTestHittableOpacity))
                    })
                    .buttonStyle(.plain)
                } else {
                    Rectangle().fill(Color.paletteClear)
                }
            }
        .frame(height: height)
        .background {
            GeometryReader { geo in
                Color.paletteClear
                    .preference(
                        key: BottomAnchorFrameKey.self,
                        value: geo.frame(in: .named("chat.messages.scrollSpace"))
                    )
            }
        }
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
