import Foundation

public protocol ChatViewModeling: Actor {
    func addChatWith(personality: UUID) async
    func delete(chatId: UUID) async
    func deleteAll() async
    func rename(chatId: UUID, newName: String) async
    func addWelcomeMessage(chatId: UUID) async
    func createPersonality(
        name: String,
        description: String,
        customSystemInstruction: String,
        category: PersonalityCategory,
        customImage: Data?
    ) async -> UUID?
}
