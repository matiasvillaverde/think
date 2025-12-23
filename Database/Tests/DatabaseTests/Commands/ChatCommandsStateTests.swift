import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands State Management Tests", .tags(.state))
struct ChatCommandsStateTests {
    @Test("Create chat reuses existing chat for same personality (1:1 relationship)")
    func createChatReusesExistingChat() async throws {
        // Given: A database with one personality
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // When: Creating chats multiple times for the same personality
        var chatIds: [UUID] = []
        for _ in 0..<5 {
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
            chatIds.append(chatId)
        }

        // Then: All chat IDs should be the same (reusing existing chat)
        let firstChatId = chatIds[0]
        for chatId in chatIds {
            #expect(chatId == firstChatId, "All creates should return the same chat ID")
        }

        // And: Only one chat should exist (1:1 relationship)
        let chatCount = try await database.read(ValidateChatCountCommand())
        #expect(chatCount == 1)
    }
}
