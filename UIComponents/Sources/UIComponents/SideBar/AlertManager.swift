import Database
import SwiftUI

public class AlertManager: ObservableObject {
    // Alert states for chats (legacy)
    @Published var showingRenameAlert: Bool = false
    @Published var showingDeleteAlert: Bool = false

    // Alert states for personalities
    @Published var showingClearConversationAlert: Bool = false
    @Published var showingDeletePersonalityAlert: Bool = false

    deinit {
        print("Alert Manager deinit")
    }

    // Chat being operated on (legacy)
    @Published var chatToModify: Chat?

    // Personality being operated on
    @Published var personalityToModify: Personality?

    // For rename operations
    @Published var renameText: String = ""

    // Prepare for a rename operation (legacy - for chats)
    func prepareRename(chat: Chat) {
        chatToModify = chat
        renameText = chat.name
        showingRenameAlert = true
    }

    // Prepare for a delete operation (legacy - for chats)
    func prepareDelete(chat: Chat) {
        chatToModify = chat
        showingDeleteAlert = true
    }

    // Prepare to clear a personality's conversation
    func prepareClearConversation(personality: Personality) {
        personalityToModify = personality
        showingClearConversationAlert = true
    }

    // Prepare to delete a custom personality
    func prepareDeletePersonality(personality: Personality) {
        personalityToModify = personality
        showingDeletePersonalityAlert = true
    }

    // Reset all states
    func reset() {
        showingRenameAlert = false
        showingDeleteAlert = false
        showingClearConversationAlert = false
        showingDeletePersonalityAlert = false
        chatToModify = nil
        personalityToModify = nil
        renameText = ""
    }
}
