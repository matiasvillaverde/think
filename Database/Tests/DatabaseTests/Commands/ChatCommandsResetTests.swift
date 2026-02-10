import Testing
import Foundation
import SwiftData
import Abstractions
import DataAssets
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands Reset Tests", .tags(.acceptance))
struct ChatCommandsResetTests {
    @Test("Reset all chats works when no chats exist")
    @MainActor
    func resetAllChatsWhenEmpty() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)

        // Verify no chats exist initially
        let initialChatCount = try await database.read(ValidateChatCountCommand())
        #expect(initialChatCount == 0)

        // When - Reset all chats (should create a new one)
        let newChatId = try await database.write(ChatCommands.ResetAllChats(systemInstruction: .empatheticFriend))

        // Then - Verify exactly 1 chat exists
        let finalChatCount = try await database.read(ValidateChatCountCommand())
        #expect(finalChatCount == 1)

        // Verify the new chat was created correctly
        let newChat = try await database.read(ChatCommands.Read(chatId: newChatId))
        #expect(newChat.id == newChatId)
        #expect(newChat.languageModelConfig.systemInstruction == SystemInstruction.empatheticFriend)
    }

    @Test("Reset all chats clears messages and resets to clean state")
    @MainActor
    func resetAllChatsClearsMessages() async throws {
        // Given: A chat with messages
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // Create a chat
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // Add a message to the chat
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test message",
            isDeepThinker: false
        ))

        // Verify chat has messages
        let chatBefore = try await database.read(ChatCommands.Read(chatId: chatId))
        #expect(chatBefore.messages.count == 1)

        // When - Reset all chats
        let start = ProcessInfo.processInfo.systemUptime
        let newChatId = try await database.write(
            ChatCommands.ResetAllChats(systemInstruction: .empatheticFriend)
        )
        let duration = ProcessInfo.processInfo.systemUptime - start

        // Then - Verify only 1 chat exists after reset
        let finalChatCount = try await database.read(ValidateChatCountCommand())
        #expect(finalChatCount == 1)

        // Verify the new chat exists and has correct system instruction
        let newChat = try await database.read(ChatCommands.Read(chatId: newChatId))
        #expect(newChat.id == newChatId)
        #expect(newChat.languageModelConfig.systemInstruction == SystemInstruction.empatheticFriend)

        // Performance check - should complete within reasonable time
        #expect(duration < 2.0, "Reset operation should complete quickly")
    }

    @Test("Reset all chats fails when no models available")
    @MainActor
    func resetAllChatsFailsWithoutModels() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        // Note: Not adding required models

        // When/Then - Should fail due to missing models
        await #expect(throws: DatabaseError.invalidInput("Cannot reset chats without both language and image models available")) {
            try await database.write(ChatCommands.ResetAllChats(systemInstruction: .empatheticFriend))
        }
    }
}

// MARK: - Helper Commands

struct GetLastUserIdCommand: ReadCommand {
    typealias Result = PersistentIdentifier
    var requiresUser: Bool { false }
    var requiresRag: Bool { false }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> PersistentIdentifier {
        let descriptor = FetchDescriptor<User>()
        guard let user = try context.fetch(descriptor).last else {
            throw DatabaseError.userNotFound
        }
        return user.persistentModelID
    }
}
