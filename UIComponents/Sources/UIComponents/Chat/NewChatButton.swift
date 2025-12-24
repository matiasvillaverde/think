import Abstractions
import Database
import OSLog
import SwiftUI

// MARK: - NewChatButton

public struct NewChatButton: View {
    @Environment(\.chatViewModel)
    var viewModel: ChatViewModeling

    @Bindable var chat: Chat

    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: String(describing: Self.self)
    )

    public var body: some View {
        Button {
            addNewChat()
        } label: {
            Label(
                String(
                    localized: "New Chat",
                    bundle: .module,
                    comment: "Button label for creating a new chat"
                ),
                systemImage: "square.and.pencil"
            )
        }
        .foregroundStyle(Color.textSecondary)
        .tint(Color.marketingSecondary)
        .font(.footnote)
    }

    // MARK: - Actions

    private func addNewChat() {
        Task(priority: .userInitiated) {
            let personalityId: UUID = chat.personality.id
            await viewModel.clearConversation(personalityId: personalityId)
        }
    }
}
