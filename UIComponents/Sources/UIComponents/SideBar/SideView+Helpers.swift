import Abstractions
import Database
import SwiftUI

// MARK: - Helper Methods Extension

extension SideView {
    /// Automatically selects the first chat from a list of new chats
    /// - Parameter newChats: Array of chat objects to select from
    func autoSelectFirstChat(newChats: [Chat]) {
        guard let firstChat = newChats.first else {
            selectedChat = nil
            return
        }

        // Always select the first chat if it's different from current selection
        if selectedChat?.id != firstChat.id {
            DispatchQueue.main.asyncAfter(deadline: .now() + smallDuration) {
                selectedChat = firstChat
            }
        }
    }

    /// Handles loading of a selected chat (currently delegates to ChatView)
    /// - Parameter newChat: The chat object to load
    func loadSelectedChat(newChat: Chat?) {
        // No longer loading models here - ChatView will handle model state
        // and show ModelDownloadingView when needed
        _ = newChat // Silence unused parameter warning
    }

    /// Performs initial setup for the side view, selecting first chat if none selected
    func initialSetup() {
        if !hasInitialized {
            hasInitialized = true
            if selectedChat == nil, !chats.isEmpty {
                selectedChat = chats.first
            }
        }
    }
}
