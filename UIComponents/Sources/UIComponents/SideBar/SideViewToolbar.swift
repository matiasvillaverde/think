import Abstractions
import Database
import OSLog
import SwiftUI

public struct SideViewToolbar: ToolbarContent {
    @Environment(\.chatViewModel)
    var viewModel: ChatViewModeling

    // MARK: - Properties

    let isSearching: Bool
    let dismissSearch: DismissSearchAction

    @Bindable var chat: Chat

    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: String(describing: Self.self)
    )

    // MARK: - Body

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            if isSearching {
                Button(
                    String(localized: "Dismiss Search", bundle: .module)
                ) {
                    dismissSearch()
                }
            }

            Button {
                addItem()
            } label: {
                Label(
                    String(
                        localized: "New Chat",
                        bundle: .module,
                        comment: "Button label for adding a new chat"
                    ),
                    systemImage: "square.and.pencil"
                )
            }
            .foregroundColor(Color.iconPrimary)
            .tint(Color.secondary)
            .font(.title2)
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    private func addItem() {
        Task(priority: .userInitiated) {
            if let id = chat.personality?.id {
                await viewModel.addChatWith(personality: id)
            } else {
                logger.error("Chat personality ID is nil")
            }
        }
    }
}
