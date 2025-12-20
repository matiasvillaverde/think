import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Memory Commands Tests")
@MainActor
struct MemoryCommandsTests {
    // MARK: - Create Tests

    @Test("Create memory successfully")
    func createMemorySuccess() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let memoryId = try await database.write(
            MemoryCommands.Create(
                type: .longTerm,
                content: "User prefers dark mode",
                keywords: ["preferences", "theme"]
            )
        )

        // Then
        let memory = try await database.read(MemoryCommands.Read(memoryId: memoryId))
        #expect(memory.type == .longTerm)
        #expect(memory.content == "User prefers dark mode")
        #expect(memory.keywords.contains("preferences"))
        #expect(memory.keywords.contains("theme"))
    }

    @Test("Create daily memory with date")
    func createDailyMemory() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)
        let today = Calendar.current.startOfDay(for: Date())

        // When
        let memoryId = try await database.write(
            MemoryCommands.Create(
                type: .daily,
                content: "Worked on Memory System",
                date: today,
                keywords: ["daily"]
            )
        )

        // Then
        let memory = try await database.read(MemoryCommands.Read(memoryId: memoryId))
        #expect(memory.type == .daily)
        #expect(memory.date != nil)
        #expect(Calendar.current.isDate(memory.date!, inSameDayAs: today))
    }

    // MARK: - UpsertSoul Tests

    @Test("Upsert soul creates new soul memory")
    func upsertSoulCreatesNew() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let memoryId = try await database.write(
            MemoryCommands.UpsertSoul(content: "I am a helpful assistant")
        )

        // Then
        let soul = try await database.read(MemoryCommands.GetSoul())
        #expect(soul != nil)
        #expect(soul?.id == memoryId)
        #expect(soul?.content == "I am a helpful assistant")
        #expect(soul?.type == .soul)
    }

    @Test("Upsert soul updates existing soul memory")
    func upsertSoulUpdatesExisting() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Create initial soul
        let firstId = try await database.write(
            MemoryCommands.UpsertSoul(content: "Initial persona")
        )

        // When - Update soul
        let secondId = try await database.write(
            MemoryCommands.UpsertSoul(content: "Updated persona")
        )

        // Then
        #expect(firstId == secondId)
        let soul = try await database.read(MemoryCommands.GetSoul())
        #expect(soul?.content == "Updated persona")
    }

    // MARK: - AppendToDaily Tests

    @Test("Append to daily creates new daily log if none exists")
    func appendToDailyCreatesNew() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let memoryId = try await database.write(
            MemoryCommands.AppendToDaily(content: "First entry")
        )

        // Then
        let memory = try await database.read(MemoryCommands.Read(memoryId: memoryId))
        #expect(memory.type == .daily)
        #expect(memory.content == "First entry")
    }

    @Test("Append to daily appends to existing daily log")
    func appendToDailyAppends() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Create first entry
        let firstId = try await database.write(
            MemoryCommands.AppendToDaily(content: "First entry")
        )

        // When - Append second entry
        let secondId = try await database.write(
            MemoryCommands.AppendToDaily(content: "Second entry")
        )

        // Then
        #expect(firstId == secondId)
        let memory = try await database.read(MemoryCommands.Read(memoryId: firstId))
        #expect(memory.content.contains("First entry"))
        #expect(memory.content.contains("Second entry"))
    }

    // MARK: - Read Tests

    @Test("Get all memories returns all user memories")
    func getAllMemories() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Create multiple memories
        _ = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "Memory 1")
        )
        _ = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "Memory 2")
        )
        _ = try await database.write(
            MemoryCommands.Create(type: .daily, content: "Daily", date: Date())
        )

        // When
        let memories = try await database.read(MemoryCommands.GetAll())

        // Then
        #expect(memories.count == 3)
    }

    @Test("Get memories by type filters correctly")
    func getByTypeFilters() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Create mixed memories
        _ = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "Long term 1")
        )
        _ = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "Long term 2")
        )
        _ = try await database.write(
            MemoryCommands.Create(type: .daily, content: "Daily", date: Date())
        )

        // When
        let longTermMemories = try await database.read(
            MemoryCommands.GetByType(type: .longTerm)
        )

        // Then
        #expect(longTermMemories.count == 2)
        #expect(longTermMemories.allSatisfy { $0.type == .longTerm })
    }

    @Test("Get recent daily logs returns logs within date range")
    func getRecentDailyLogs() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let today = Calendar.current.startOfDay(for: Date())

        // Create today's log
        _ = try await database.write(
            MemoryCommands.Create(type: .daily, content: "Today's log", date: today)
        )

        // When
        let recentLogs = try await database.read(
            MemoryCommands.GetRecentDailyLogs(days: 2)
        )

        // Then
        #expect(recentLogs.count == 1)
        #expect(recentLogs.first?.content == "Today's log")
    }

    @Test("Get memory context returns complete context")
    func getMemoryContext() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Create soul
        _ = try await database.write(
            MemoryCommands.UpsertSoul(content: "I am helpful")
        )

        // Create long-term memories
        _ = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "User likes Swift")
        )

        // Create daily log
        _ = try await database.write(
            MemoryCommands.AppendToDaily(content: "Worked on tests")
        )

        // When
        let context = try await database.read(
            MemoryCommands.GetMemoryContext()
        )

        // Then
        #expect(context.soul != nil)
        #expect(context.soul?.content == "I am helpful")
        #expect(context.longTermMemories.count == 1)
        #expect(context.recentDailyLogs.count == 1)
        #expect(!context.isEmpty)
    }

    // MARK: - Update Tests

    @Test("Update memory content")
    func updateMemoryContent() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let memoryId = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "Original content")
        )

        // When
        _ = try await database.write(
            MemoryCommands.Update(memoryId: memoryId, content: "Updated content")
        )

        // Then
        let memory = try await database.read(MemoryCommands.Read(memoryId: memoryId))
        #expect(memory.content == "Updated content")
    }

    @Test("Add keywords to memory")
    func addKeywords() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let memoryId = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "Test", keywords: ["initial"])
        )

        // When
        _ = try await database.write(
            MemoryCommands.AddKeywords(memoryId: memoryId, keywords: ["new", "keywords"])
        )

        // Then
        let memory = try await database.read(MemoryCommands.Read(memoryId: memoryId))
        #expect(memory.keywords.contains("initial"))
        #expect(memory.keywords.contains("new"))
        #expect(memory.keywords.contains("keywords"))
    }

    // MARK: - Delete Tests

    @Test("Delete memory by ID")
    func deleteMemory() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let memoryId = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "To be deleted")
        )

        // When
        _ = try await database.write(MemoryCommands.Delete(memoryId: memoryId))

        // Then
        do {
            _ = try await database.read(MemoryCommands.Read(memoryId: memoryId))
            Issue.record("Expected memoryNotFound error")
        } catch DatabaseError.memoryNotFound {
            // Expected
        }
    }

    @Test("Delete memories by type")
    func deleteByType() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // Create mixed memories
        _ = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "Long term 1")
        )
        _ = try await database.write(
            MemoryCommands.Create(type: .longTerm, content: "Long term 2")
        )
        _ = try await database.write(
            MemoryCommands.Create(type: .daily, content: "Daily", date: Date())
        )

        // When
        _ = try await database.write(MemoryCommands.DeleteByType(type: .longTerm))

        // Then
        let longTermMemories = try await database.read(
            MemoryCommands.GetByType(type: .longTerm)
        )
        let dailyMemories = try await database.read(
            MemoryCommands.GetByType(type: .daily)
        )
        #expect(longTermMemories.isEmpty)
        #expect(dailyMemories.count == 1)
    }

    @Test("Prune old daily logs")
    func pruneOldDailyLogs() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oldDate = calendar.date(byAdding: .day, value: -10, to: today)!

        // Create old and recent logs
        _ = try await database.write(
            MemoryCommands.Create(type: .daily, content: "Old log", date: oldDate)
        )
        _ = try await database.write(
            MemoryCommands.Create(type: .daily, content: "Today's log", date: today)
        )

        // When
        _ = try await database.write(MemoryCommands.PruneDailyLogs(olderThanDays: 7))

        // Then
        let dailyLogs = try await database.read(MemoryCommands.GetByType(type: .daily))
        #expect(dailyLogs.count == 1)
        #expect(dailyLogs.first?.content == "Today's log")
    }
}
