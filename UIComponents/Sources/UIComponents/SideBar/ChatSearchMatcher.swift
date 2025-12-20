import Database
import Foundation

/// Utility for matching chats against search criteria
public enum ChatSearchMatcher {
    /// Checks if a Chat matches the current search criteria (scopes + text + tokens).
    static func matches(
        chat: Chat,
        searchTokens: [ModelToken],
        searchText: String,
        searchScope: ChatSearchScope
    ) -> Bool {
        // If the user has added any tokens, treat them as "must be in chat's models"
        if !searchTokens.isEmpty {
            guard let user = chat.user else {
                return false
            }

            let chatModelNames: [String] = user.models
                .filter { $0.type == .language }
                .map { $0.displayName.lowercased() }

            // At least one token must appear in the chat's model set
            let anyTokenMatches: Bool = searchTokens.contains { token in
                chatModelNames.contains(token.displayName.lowercased())
            }

            if !anyTokenMatches {
                return false
            }
        }

        // Lowercased version of search text
        let text: String = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else {
            // If searchText is empty but we had tokens, we already handled them above
            return true
        }

        switch searchScope {
        case .all:
            // Must match either the name or any message content (including the model's displayName)
            return chat.name.lowercased().contains(text)
                || chat.messages.contains { message in
                    messageMatchesSearch(message: message, text: text)
                }

        case .name:
            // Only the chat name and model
            return chat.name.lowercased().contains(text)
                || chat.languageModel.displayName.lowercased().contains(text)

        case .messages:
            // Only the messages (including the model's displayName)
            return chat.messages.contains { message in
                messageMatchesSearch(message: message, text: text)
            }
        }
    }

    private static func messageMatchesSearch(message: Message, text: String) -> Bool {
        message.userInput?.lowercased().contains(text) == true
            || message.response?.lowercased().contains(text) == true
            || message.thinking?.lowercased().contains(text) == true
            || message.languageModel.displayName.lowercased().contains(text) == true
    }
}
