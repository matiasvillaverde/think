import Abstractions
import Database
import SwiftUI

public struct DeleteConfirmationActions: View {
    @Environment(\.chatViewModel)
    var viewModel: ChatViewModeling

    @Bindable var chat: Chat

    // MARK: - Body

    public var body: some View {
        Group {
            Button(
                String(localized: "Cancel", bundle: .module, comment: "Button label"),
                role: .cancel
            ) {
                print("Cancelled")
            }

            Button(
                String(localized: "Delete", bundle: .module, comment: "Button label"),
                role: .destructive
            ) {
                onDelete()
            }
        }
    }

    private func onDelete() {
        Task(priority: .userInitiated) {
            await viewModel.delete(chatId: chat.id)
        }
    }
}
