import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Chat Commands Edge Cases Tests", .tags(.edge))
struct ChatCommandsEdgeCaseTests {
    @Test("Delete nonexistent chat fails")
    func deleteNonexistentChat() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)

        // When/Then
        await #expect(throws: DatabaseError.chatNotFound) {
            try await database.write(ChatCommands.Delete(id: UUID()))
        }
    }
}
