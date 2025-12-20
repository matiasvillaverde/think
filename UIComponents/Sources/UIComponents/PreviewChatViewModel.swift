import Abstractions
import DataAssets
import Foundation
import OSLog

/// Default view model implementation for chat functionality in previews
internal final actor PreviewChatViewModel: ChatViewModeling {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "UI"
    )

    func addChatWith(personality: UUID) {
        logger.warning("Default view model - Add chat called \(personality.hashValue)")
    }

    func addChat() {
        logger.warning("Default view model - Add chat called")
    }

    func addChat(systemInstruction: SystemInstruction) {
        logger.warning("Default view model - Add chat called \(systemInstruction.hashValue)")
    }

    func delete(chatId: UUID) {
        logger.warning("Default view model - Delete chat called: \(chatId)")
    }

    func deleteAll() {
        logger.warning("Default view model - DeleteAll called")
    }

    func rename(chatId: UUID, newName: String) {
        logger.warning("Default view model - Rename chat called: \(chatId) to \(newName)")
    }

    func addWelcomeMessage(chatId: UUID) {
        logger.warning("Default view model - add welcome message called: \(chatId)")
    }

    func createPersonality(
        name: String,
        description: String,
        customSystemInstruction: String,
        category _: PersonalityCategory,
        customImage _: Data?
    ) -> UUID? {
        logger.warning("\(name), \(description), \(customSystemInstruction)")
        return nil
    }
}
