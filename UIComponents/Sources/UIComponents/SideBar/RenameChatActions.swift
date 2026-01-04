import Abstractions
import Database
import SwiftUI

public struct RenameChatActions: View {
    @Environment(\.chatViewModel)
    var viewModel: ChatViewModeling

    // MARK: - Properties

    @Bindable var chat: Chat
    @Binding var renameText: String

    // MARK: - Body

    public var body: some View {
        Group {
            TextField(
                String(
                    localized: "New title",
                    bundle: .module,
                    comment: "Text for the text field in the rename chat sheet"
                ),
                text: $renameText
            )

            Button(
                String(localized: "Cancel", bundle: .module, comment: "Button label"),
                role: .cancel
            ) {
                // no-op
            }

            Button(
                String(localized: "Save", bundle: .module, comment: "Button label")
            ) {
                onSave()
            }
        }
    }

    private func onSave() {
        let trimmedName: String = renameText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task(priority: .userInitiated) {
            await viewModel.rename(chatId: chat.id, newName: trimmedName)
        }
    }
}
