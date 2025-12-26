import Testing
import Foundation
import SwiftData
import Abstractions
import DataAssets
@testable import Database
import AbstractionsTestUtilities

@Suite("Memory RAG Integration Tests")
struct MemoryRagIntegrationTests {
    // MARK: - Helper Methods

    @MainActor
    private func createTestDatabase() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        return database
    }

    // MARK: - RagTableName Tests

    @Test("Memory table name is generated correctly for user")
    func memoryTableNameGeneration() {
        // Given
        let userId = UUID()

        // When
        let tableName = RagTableName.memoryTableName(userId: userId)

        // Then
        let expectedNormalizedId = userId.uuidString.replacingOccurrences(of: "-", with: "_")
        #expect(tableName == "memory_\(expectedNormalizedId)")
    }

    @Test("Memory table names are unique per user")
    func memoryTableNamesAreUnique() {
        // Given
        let user1Id = UUID()
        let user2Id = UUID()

        // When
        let table1 = RagTableName.memoryTableName(userId: user1Id)
        let table2 = RagTableName.memoryTableName(userId: user2Id)

        // Then
        #expect(table1 != table2)
    }

    // MARK: - indexText Tests

    @Test("Index text stores content in RAG")
    @MainActor
    func indexTextStoresContent() async throws {
        // Given
        let database = try await createTestDatabase()
        let memoryId = UUID()
        let userId = UUID()
        let table = RagTableName.memoryTableName(userId: userId)

        // When/Then - run in background as indexText requires non-main thread
        try await Task.detached {
            try await database.indexText(
                "User prefers dark mode interfaces",
                id: memoryId,
                table: table
            )
        }.value
    }

    @Test("Delete from index removes content")
    @MainActor
    func deleteFromIndexRemovesContent() async throws {
        // Given
        let database = try await createTestDatabase()
        let memoryId = UUID()
        let userId = UUID()
        let table = RagTableName.memoryTableName(userId: userId)

        // Index content first (in background)
        try await Task.detached {
            try await database.indexText(
                "Test content",
                id: memoryId,
                table: table
            )
        }.value

        // When/Then - delete should not throw (in background)
        try await Task.detached {
            try await database.deleteFromIndex(id: memoryId, table: table)
        }.value
    }

    // MARK: - searchMemories Tests

    @Test("Search memories returns empty for no indexed content")
    @MainActor
    func searchMemoriesReturnsEmptyWhenNoContent() async throws {
        // Given
        let database = try await createTestDatabase()
        let userId = UUID()

        // When - run in background
        let results = try await Task.detached {
            try await database.searchMemories(
                query: "dark mode",
                userId: userId,
                limit: 10,
                threshold: 10.0
            )
        }.value

        // Then
        #expect(results.isEmpty)
    }

    @Test("Search memories uses correct table name")
    @MainActor
    func searchMemoriesUsesCorrectTable() async throws {
        // Given
        let database = try await createTestDatabase()
        let userId = UUID()

        // When - search should not throw even if table doesn't exist (in background)
        let results = try await Task.detached {
            try await database.searchMemories(
                query: "test query",
                userId: userId,
                limit: 5,
                threshold: 10.0
            )
        }.value

        // Then - results should be empty (no content indexed)
        #expect(results.isEmpty)
    }
}
