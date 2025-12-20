import Database
import SwiftUI

public struct ChatSections: View {
    // MARK: - Properties

    let chatsToday: [Chat]
    let chatsYesterday: [Chat]
    let chatsPast: [Chat]
    let alertManager: AlertManager

    // MARK: - Body

    public var body: some View {
        Group {
            todaySection
            yesterdaySection
            pastSection
        }
    }

    @ViewBuilder private var todaySection: some View {
        if !chatsToday.isEmpty {
            Section(
                String(
                    localized: "Today",
                    bundle: .module,
                    comment: "Chats section header for chats of today"
                )
            ) {
                ChatListSection(
                    chats: chatsToday,
                    alertManager: alertManager
                )
            }
        }
    }

    @ViewBuilder private var yesterdaySection: some View {
        if !chatsYesterday.isEmpty {
            Section(
                String(
                    localized: "Yesterday",
                    bundle: .module,
                    comment: "Chats section header for chats of yesterday"
                )
            ) {
                ChatListSection(
                    chats: chatsYesterday,
                    alertManager: alertManager
                )
            }
        }
    }

    @ViewBuilder private var pastSection: some View {
        if !chatsPast.isEmpty {
            Section(
                String(
                    localized: "Past",
                    bundle: .module,
                    comment: "Chats section header for chats of the far past"
                )
            ) {
                ChatListSection(
                    chats: chatsPast,
                    alertManager: alertManager
                )
            }
        }
    }
}
