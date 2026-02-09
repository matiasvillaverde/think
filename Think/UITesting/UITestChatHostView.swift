import Database
import SwiftData
import SwiftUI
import UIComponents

/// Host that always shows the first available chat.
internal struct UITestChatHostView: View {
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]

    internal var body: some View {
        if let chat = chats.first {
            ZStack(alignment: .topLeading) {
                ChatView(chat: chat)
                    .accessibilityIdentifier("uiTest.chatView")

                UITestStreamingProbeView()
            }
        } else {
            ProgressView()
                .accessibilityIdentifier("uiTest.loading")
        }
    }
}
