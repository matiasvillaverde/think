import Database
import SwiftUI

public struct ChatListSection: View {
    // **MARK: - Properties**
    let chats: [Chat] // Here have a Query, instead of at the SideView level
    let alertManager: AlertManager

    // **MARK: - Body**
    public var body: some View {
        ForEach(chats, id: \.id) { chat in
            NavigationLink(value: chat) {
                SidebarItemView(chat: chat)
            }
            .swipeActions(allowsFullSwipe: true) {
                Button {
                    onRename(chat: chat)
                } label: {
                    Label(
                        String(
                            localized: "Rename",
                            bundle: .module,
                            comment: "Chat list sidebar rename action of a chat title"
                        ),
                        systemImage: "pencil"
                    )
                }
                .tint(Color.iconInfo)
                swipeDeleteButton(chat: chat)
            }
            .contextMenu {
                contextMenuRename(chat: chat)
                contextMenuDelete(chat: chat)
            }
        }
    }

    private func swipeDeleteButton(chat: Chat) -> some View {
        Button(role: .none) {
            onDelete(chat: chat)
        } label: {
            Label(
                String(
                    localized: "Delete",
                    bundle: .module,
                    comment: "Chat list sidebar delete action"
                ),
                systemImage: "trash.fill"
            )
        }
    }

    private func contextMenuRename(chat: Chat) -> some View {
        Button {
            onRename(chat: chat)
        } label: {
            Label(
                String(
                    localized: "Rename",
                    bundle: .module,
                    comment: "Context menu rename action of a chat title"
                ),
                systemImage: "pencil"
            )
            .font(.system(size: Layout.contextMenuIconSize))
        }
    }

    private func contextMenuDelete(chat: Chat) -> some View {
        Button(role: .none) {
            onDelete(chat: chat)
        } label: {
            Label(
                String(
                    localized: "Delete",
                    bundle: .module,
                    comment: "Context menu delete action"
                ),
                systemImage: "trash"
            )
            .font(.system(size: Layout.contextMenuIconSize))
        }
        .background(Color.iconAlert)
    }

    // Update these functions to use the AlertManager
    private func onRename(chat: Chat) {
        alertManager.prepareRename(chat: chat)
    }

    private func onDelete(chat: Chat) {
        alertManager.prepareDelete(chat: chat)
    }
}

// **MARK: - Previews**
#if DEBUG
    #Preview {
        ChatListSection(chats: [Chat.preview], alertManager: AlertManager())
    }
#endif
