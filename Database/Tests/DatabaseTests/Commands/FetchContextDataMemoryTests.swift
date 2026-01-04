import Testing
import Foundation
import SwiftData
import Abstractions
import DataAssets
@testable import Database
import AbstractionsTestUtilities

@Suite("FetchContextData Memory Context Tests")
@MainActor
struct FetchContextDataMemoryTests {
    // MARK: - Helper Methods

    /// Creates a test database with personalities, models, and a chat
    private func createTestDatabaseWithChat() async throws -> (Database, UUID) {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)

        // Add required models and default personality (using existing helper)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // Create a chat
        let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        return (database, chatId)
    }

    // MARK: - Memory Context Tests

    @Test("FetchContextData includes personality memory context")
    func fetchContextDataIncludesPersonalityMemoryContext() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // Get the chat's personality
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        let personalityId = chat.personality.id

        // Create soul for the personality
        _ = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personalityId,
                content: "I am a helpful assistant who loves to explain things clearly."
            )
        )

        // Create long-term memory for personality
        _ = try await database.write(
            MemoryCommands.CreatePersonalityMemory(
                personalityId: personalityId,
                type: .longTerm,
                content: "User prefers concise responses."
            )
        )

        // When
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then
        #expect(contextConfig.memoryContext != nil)
        #expect(contextConfig.memoryContext?.soul != nil)
        #expect(contextConfig.memoryContext?.soul?.content == "I am a helpful assistant who loves to explain things clearly.")
        #expect(contextConfig.memoryContext?.longTermMemories.count == 1)
        #expect(contextConfig.memoryContext?.longTermMemories.first?.content == "User prefers concise responses.")
    }

    @Test("FetchContextData includes daily logs in memory context")
    func fetchContextDataIncludesDailyLogs() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // Get the chat's personality
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        let personalityId = chat.personality.id

        // Create daily log for the personality
        _ = try await database.write(
            MemoryCommands.AppendToPersonalityDaily(
                personalityId: personalityId,
                content: "Had a productive coding session today."
            )
        )

        // When
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then
        #expect(contextConfig.memoryContext != nil)
        #expect(contextConfig.memoryContext?.recentDailyLogs.count == 1)
        #expect(contextConfig.memoryContext?.recentDailyLogs.first?.content.contains("productive coding session") == true)
    }

    @Test("FetchContextData returns nil memoryContext when personality has no memories")
    func fetchContextDataReturnsNilWhenNoMemories() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // When - Fetch context without creating any memories
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then - memoryContext should be nil or empty (depending on implementation)
        let isEmpty = contextConfig.memoryContext?.isEmpty ?? true
        #expect(isEmpty == true, "Memory context should be empty when no memories exist")
    }

    @Test("Soul is included in memory context")
    func soulIsIncludedInMemoryContext() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // Get the chat's personality
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        let personalityId = chat.personality.id

        // Create only a soul (no other memories)
        _ = try await database.write(
            MemoryCommands.UpsertPersonalitySoul(
                personalityId: personalityId,
                content: "I approach every conversation with curiosity and respect."
            )
        )

        // When
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then
        #expect(contextConfig.memoryContext?.soul != nil)
        #expect(contextConfig.memoryContext?.soul?.type == .soul)
        #expect(contextConfig.memoryContext?.isEmpty == false)
    }

    @Test("Long-term memories are included in context")
    func longTermMemoriesAreIncludedInContext() async throws {
        // Given
        let (database, chatId) = try await createTestDatabaseWithChat()

        // Get the chat's personality
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        let personalityId = chat.personality.id

        // Create multiple long-term memories
        _ = try await database.write(
            MemoryCommands.CreatePersonalityMemory(
                personalityId: personalityId,
                type: .longTerm,
                content: "User prefers dark mode."
            )
        )
        _ = try await database.write(
            MemoryCommands.CreatePersonalityMemory(
                personalityId: personalityId,
                type: .longTerm,
                content: "User works with Swift regularly."
            )
        )

        // When
        let contextConfig = try await database.read(ChatCommands.FetchContextData(chatId: chatId))

        // Then
        #expect(contextConfig.memoryContext?.longTermMemories.count == 2)
    }
}
