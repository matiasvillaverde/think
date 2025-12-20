import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands State Management Tests", .tags(.state))
struct ChatCommandsStateTests {
    @Test("Create multiple chats maintains consistency")
    func createMultipleChats() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        let defaultPersonalityId = try await getDefaultPersonalityId(database)

        // When
        for _ in 0..<5 {
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        }

        // Then
        let chatCount = try await database.read(ValidateChatCountCommand())
        #expect(chatCount == 5)
    }
}
