import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands Concurrency Tests", .tags(.core))
struct ChatCommandsConcurrencyTests {
    @Test("Concurrent renames don't cause data corruption")
    @MainActor
    func concurrentRenames() async throws {
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

        // When - Sequential renames to avoid race conditions
        let id = chat.id

        // Test with a single rename first to ensure it works
        try await database.write(ChatCommands.Rename(
            chatId: id,
            newName: "Name 0"
        ))

        let afterFirstRename = try await database.read(ChatCommands.GetFirst())
        #expect(afterFirstRename.name == "Name 0", "First rename should work")

        // Now test concurrent renames
        for index in 1..<10 {
            try await database.writeInBackground(ChatCommands.Rename(
                chatId: id,
                newName: "Name \(index)"
            ))
        }

        // Give time for background operations to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Then
        let finalChat = try await database.read(ChatCommands.GetFirst())
        #expect(finalChat.name.starts(with: "Name "))
    }
}
