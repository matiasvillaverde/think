import Database
import SwiftUI

public class AlertManager: ObservableObject {
    // Alert states
    @Published var showingRenameAlert: Bool = false
    @Published var showingDeleteAlert: Bool = false

    deinit {
        print("Alert Manager deinit")
    }

    // Chat being operated on
    @Published var chatToModify: Chat?

    // For rename operations
    @Published var renameText: String = ""

    // Prepare for a rename operation
    func prepareRename(chat: Chat) {
        chatToModify = chat
        renameText = chat.name
        showingRenameAlert = true
    }

    // Prepare for a delete operation
    func prepareDelete(chat: Chat) {
        chatToModify = chat
        showingDeleteAlert = true
    }

    // Reset all states
    func reset() {
        showingRenameAlert = false
        showingDeleteAlert = false
        chatToModify = nil
        renameText = ""
    }
}
