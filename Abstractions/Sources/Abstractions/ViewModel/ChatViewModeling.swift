import Foundation

public protocol ChatViewModeling: Actor {
    // MARK: - Legacy Chat Operations (deprecated)

    /// Creates a new chat for the given personality
    /// - Note: Deprecated. Use selectPersonality instead.
    func addChatWith(personality: UUID) async

    /// Deletes a chat by ID
    /// - Note: Deprecated. Use clearConversation or deletePersonality instead.
    func delete(chatId: UUID) async

    /// Deletes all chats
    /// - Note: Deprecated.
    func deleteAll() async

    /// Renames a chat
    /// - Note: Deprecated.
    func rename(chatId: UUID, newName: String) async

    /// Adds a welcome message to a chat
    func addWelcomeMessage(chatId: UUID) async

    // MARK: - Personality-First Operations

    /// Selects a personality and ensures its chat is ready
    /// This creates the chat if it doesn't exist and adds a welcome message
    func selectPersonality(personalityId: UUID) async

    /// Clears all messages from a personality's conversation
    /// The personality and chat are preserved, only messages are deleted
    func clearConversation(personalityId: UUID) async

    /// Deletes a custom personality and its associated chat
    func deletePersonality(personalityId: UUID) async

    // MARK: - Personality Management

    /// Creates a new custom personality with an associated chat
    func createPersonality(
        name: String,
        description: String,
        customSystemInstruction: String,
        category: PersonalityCategory,
        customImage: Data?
    ) async -> UUID?
}
