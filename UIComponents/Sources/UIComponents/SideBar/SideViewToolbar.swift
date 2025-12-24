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

    @Bindable var personality: Personality

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
                clearConversation()
            } label: {
                Label(
                    String(
                        localized: "Clear Conversation",
                        bundle: .module,
                        comment: "Button label for clearing the current conversation"
                    ),
                    systemImage: "trash"
                )
            }
            .foregroundColor(Color.iconPrimary)
            .tint(Color.secondary)
            .font(.title2)
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }
    }

    private func clearConversation() {
        Task(priority: .userInitiated) {
            await viewModel.clearConversation(personalityId: personality.id)
        }
    }
}
