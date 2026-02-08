import Database
import SwiftData
import SwiftUI
import UIComponents

/// Host that always shows the first available chat.
internal struct UITestChatHostView: View {
    @Query(sort: \Chat.createdAt) private var chats: [Chat]

    internal var body: some View {
        if let chat = chats.first {
            ChatView(chat: chat)
                .accessibilityIdentifier("uiTest.chatView")
        } else {
            ProgressView()
                .accessibilityIdentifier("uiTest.loading")
        }
    }
}
