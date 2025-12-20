import Abstractions
import Database
import SwiftUI

// MARK: - Search Helper Extension

extension SideView {
    /// Collect unique displayNames from all chats, for demonstration as "model suggestions".
    func availableModelDisplayNames() -> [String] {
        let modelNames: Set<String> = Set(
            chats
                .compactMap(\.user)
                .flatMap(\.models)
                .compactMap { model in
                    // Defensive check: ensure displayName is not empty
                    let name: String = model.displayName
                    return name.isEmpty ? nil : name
                }
        )
        return modelNames.sorted()
    }

    /// Determines if a given chat matches the current search criteria.
    func matchesSearch(chat: Chat) -> Bool {
        ChatSearchMatcher.matches(
            chat: chat,
            searchTokens: searchTokens,
            searchText: searchText,
            searchScope: searchScope
        )
    }
}

// MARK: - Filtered Chats Extension

extension SideView {
    /// The full list of chats, filtered by the current search text, tokens, and scope.
    var filteredChats: [Chat] {
        guard !searchText.isEmpty || !searchTokens.isEmpty else {
            return chats // no filtering
        }
        return chats.filter { chat in
            matchesSearch(chat: chat)
        }
    }

    /// For today's date grouping, filter from the *filtered* chats
    var chatsToday: [Chat] {
        filteredChats.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    /// Filtered chats from yesterday's date
    var chatsYesterday: [Chat] {
        filteredChats.filter { Calendar.current.isDateInYesterday($0.createdAt) }
    }

    /// Filtered chats from dates before yesterday
    var chatsPast: [Chat] {
        filteredChats.filter { chat in
            !Calendar.current.isDateInToday(chat.createdAt) &&
                !Calendar.current.isDateInYesterday(chat.createdAt)
        }
    }
}
