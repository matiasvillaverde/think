import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands Rename Tests", .tags(.acceptance))
struct ChatCommandsRenameTests {
    @Test("Rename chat successfully")
    @MainActor
    func renameChatSuccess() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        let chat = try await database.read(ChatCommands.GetFirst())
        let newName = "New Chat Name"

        // When
        try await database.write(ChatCommands.Rename(chatId: chat.id, newName: newName))

        // Then
        let updatedChat = try await database.read(ChatCommands.GetFirst())
        #expect(updatedChat.name == newName)
    }

    @Test("Rename chat with empty string fails")
    @MainActor
    func renameChatEmptyString() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        let chat = try await database.read(ChatCommands.GetFirst())

        // When/Then
        await #expect(throws: DatabaseError.self) {
            try await database.write(ChatCommands.Rename(chatId: chat.id, newName: ""))
        }
    }

    @Test("Rename nonexistent chat fails")
    func renameNonexistentChat() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)

        // When/Then
        await #expect(throws: DatabaseError.chatNotFound) {
            try await database.write(ChatCommands.Rename(
                chatId: UUID(),
                newName: "New Name"
            ))
        }
    }

    @Test("Rename chat with very long name fails")
    @MainActor
    func renameChatLongName() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        let chat = try await database.read(ChatCommands.GetFirst())
        let longName = String(repeating: "a", count: 1001)

        // When/Then
        await #expect(throws: DatabaseError.self) {
            try await database.write(ChatCommands.Rename(
                chatId: chat.id,
                newName: longName
            ))
        }
    }
}
