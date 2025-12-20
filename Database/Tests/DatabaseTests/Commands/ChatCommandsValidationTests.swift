import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands Validation Tests", .tags(.core))
struct ChatCommandsValidationTests {
    @Test("Rename chat with invalid characters fails")
    @MainActor
    func renameChatInvalidChars() async throws {
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

        // When/Then - Test with control characters which are truly invalid
        await #expect(throws: DatabaseError.self) {
            try await database.write(ChatCommands.Rename(
                chatId: chat.id,
                newName: "Invalid\u{0000}Name"  // Null character
            ))
        }
    }

    @Test("Rename chat with only whitespace fails")
    @MainActor
    func renameChatWhitespace() async throws {
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
            try await database.write(ChatCommands.Rename(
                chatId: chat.id,
                newName: "   "
            ))
        }
    }
}
