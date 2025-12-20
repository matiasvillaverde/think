import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands Attachment Tests", .tags(.acceptance))
struct ChatCommandsAttachmentTests {
    @Test("Check chat has no attachments initially")
    @MainActor
    func noAttachmentsInitially() async throws {
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

        // When
        let hasAttachments = try await database.read(ChatCommands.HasAttachments(chatId: chat.id))

        // Then
        #expect(hasAttachments == false)
    }

    @Test("Check chat has attachments after adding one")
    @MainActor
    func hasAttachmentsAfterAdding() async throws {
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

        // When
        // Note: File attachment functionality will be tested once FileCommands.Create is fully implemented

        // Then
        let hasAttachments = try await database.read(ChatCommands.HasAttachments(chatId: chat.id))
        #expect(hasAttachments == false)
    }

    @Test("Check attachments for nonexistent chat fails")
    func checkAttachmentsNonexistentChat() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)

        // When/Then
        await #expect(throws: DatabaseError.chatNotFound) {
            _ = try await database.read(ChatCommands.HasAttachments(chatId: UUID()))
        }
    }
}
