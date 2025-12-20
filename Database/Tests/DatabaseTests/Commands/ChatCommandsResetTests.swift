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
        let newChatId = try await database.write(ChatCommands.ResetAllChats(systemInstruction: .englishAssistant))

        // Then - Verify exactly 1 chat exists
        let finalChatCount = try await database.read(ValidateChatCountCommand())
        #expect(finalChatCount == 1)

        // Verify the new chat was created correctly
        let newChat = try await database.read(ChatCommands.Read(chatId: newChatId))
        #expect(newChat.id == newChatId)
        #expect(newChat.languageModelConfig.systemInstruction == SystemInstruction.englishAssistant)
    }

    @Test("Reset all chats handles large number of chats (50)")
    @MainActor
    func resetAllChatsWithLargeDataset() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // Create 50 chats with alternating system instructions
        var createdChatIds: [UUID] = []

        for _ in 0..<50 {
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
            createdChatIds.append(chatId)
        }

        // Verify we have exactly 50 chats
        let initialChatCount = try await database.read(ValidateChatCountCommand())
        #expect(initialChatCount == 50)

        // When - Reset all chats
        let start = ProcessInfo.processInfo.systemUptime
        let newChatId = try await database.write(ChatCommands.ResetAllChats(systemInstruction: .englishAssistant))
        let duration = ProcessInfo.processInfo.systemUptime - start

        // Then - Verify only 1 chat exists after reset
        let finalChatCount = try await database.read(ValidateChatCountCommand())
        #expect(finalChatCount == 1)

        // Verify the new chat exists and has correct system instruction
        let newChat = try await database.read(ChatCommands.Read(chatId: newChatId))
        #expect(newChat.id == newChatId)
        #expect(newChat.languageModelConfig.systemInstruction == SystemInstruction.englishAssistant)

        // Performance check - should complete within reasonable time
        #expect(duration < 2.0, "Reset operation should complete within 2 seconds even with 50 chats")
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
            try await database.write(ChatCommands.ResetAllChats(systemInstruction: .englishAssistant))
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
