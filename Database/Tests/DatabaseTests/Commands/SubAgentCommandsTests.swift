import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("SubAgent Commands Tests")
@MainActor
struct SubAgentCommandsTests {
    // MARK: - Create Tests

    @Test("Create sub-agent run successfully")
    func createSubAgentRunSuccess() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let runId = try await database.write(
            SubAgentCommands.Create(
                prompt: "Research Swift concurrency",
                mode: .background,
                tools: ["browser.search", "duckduckgo_search"]
            )
        )

        // Then
        let run = try await database.read(SubAgentCommands.Read(runId: runId))
        #expect(run.prompt == "Research Swift concurrency")
        #expect(run.mode == .background)
        #expect(run.status == .running)
        #expect(run.tools.contains("browser.search"))
    }

    @Test("Create sub-agent run with parallel mode")
    func createSubAgentRunParallelMode() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        // When
        let runId = try await database.write(
            SubAgentCommands.Create(
                prompt: "Parallel task",
                mode: .parallel
            )
        )

        // Then
        let run = try await database.read(SubAgentCommands.Read(runId: runId))
        #expect(run.mode == .parallel)
    }

    // MARK: - Read Tests

    @Test("GetActive returns only running sub-agents")
    func getActiveReturnsOnlyRunning() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let runId1 = try await database.write(
            SubAgentCommands.Create(prompt: "Task 1", mode: .background)
        )
        let runId2 = try await database.write(
            SubAgentCommands.Create(prompt: "Task 2", mode: .background)
        )

        // Complete one of them
        try await database.write(
            SubAgentCommands.MarkCompleted(
                runId: runId1,
                output: "Done",
                toolsUsed: [],
                durationMs: 100
            )
        )

        // When
        let activeRuns = try await database.read(SubAgentCommands.GetActive())

        // Then
        #expect(activeRuns.count == 1)
        #expect(activeRuns.first?.id == runId2)
    }

    // MARK: - Update Tests

    @Test("Mark completed updates run status")
    func markCompletedUpdatesStatus() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let runId = try await database.write(
            SubAgentCommands.Create(prompt: "Task", mode: .background)
        )

        // When
        try await database.write(
            SubAgentCommands.MarkCompleted(
                runId: runId,
                output: "Task completed successfully",
                toolsUsed: ["python_exec"],
                durationMs: 5_000
            )
        )

        // Then
        let run = try await database.read(SubAgentCommands.Read(runId: runId))
        #expect(run.status == .completed)
        #expect(run.output == "Task completed successfully")
        #expect(run.toolsUsed.contains("python_exec"))
        #expect(run.durationMs == 5_000)
        #expect(run.completedAt != nil)
    }

    @Test("Mark failed updates run status")
    func markFailedUpdatesStatus() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let runId = try await database.write(
            SubAgentCommands.Create(prompt: "Task", mode: .background)
        )

        // When
        try await database.write(
            SubAgentCommands.MarkFailed(
                runId: runId,
                error: "Network error",
                durationMs: 1_000
            )
        )

        // Then
        let run = try await database.read(SubAgentCommands.Read(runId: runId))
        #expect(run.status == .failed)
        #expect(run.errorMessage == "Network error")
    }

    @Test("Mark timed out updates run status")
    func markTimedOutUpdatesStatus() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let runId = try await database.write(
            SubAgentCommands.Create(prompt: "Task", mode: .background)
        )

        // When
        try await database.write(
            SubAgentCommands.MarkTimedOut(runId: runId, durationMs: 2_000)
        )

        // Then
        let run = try await database.read(SubAgentCommands.Read(runId: runId))
        #expect(run.status == .timedOut)
        #expect(run.errorMessage == "Sub-agent execution timed out")
    }

    @Test("Mark cancelled updates run status")
    func markCancelledUpdatesStatus() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let runId = try await database.write(
            SubAgentCommands.Create(prompt: "Task", mode: .background)
        )

        // When
        try await database.write(
            SubAgentCommands.MarkCancelled(runId: runId, durationMs: 500)
        )

        // Then
        let run = try await database.read(SubAgentCommands.Read(runId: runId))
        #expect(run.status == .cancelled)
    }

    // MARK: - Delete Tests

    @Test("Delete removes sub-agent run")
    func deleteRemovesRun() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let runId = try await database.write(
            SubAgentCommands.Create(prompt: "Task", mode: .background)
        )

        // When
        try await database.write(SubAgentCommands.Delete(runId: runId))

        // Then
        await #expect(throws: DatabaseError.subAgentRunNotFound) {
            _ = try await database.read(SubAgentCommands.Read(runId: runId))
        }
    }

    // MARK: - Convert to Result Tests

    @Test("toResult converts run to SubAgentResult")
    func toResultConvertsRun() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await waitForStatus(database, expectedStatus: .ready)

        let runId = try await database.write(
            SubAgentCommands.Create(prompt: "Task", mode: .background)
        )
        try await database.write(
            SubAgentCommands.MarkCompleted(
                runId: runId,
                output: "Done",
                toolsUsed: ["browser.search"],
                durationMs: 2_000
            )
        )

        // When
        let run = try await database.read(SubAgentCommands.Read(runId: runId))
        let result = run.toResult()

        // Then
        #expect(result.id == runId)
        #expect(result.status == .completed)
        #expect(result.output == "Done")
        #expect(result.toolsUsed == ["browser.search"])
        #expect(result.durationMs == 2_000)
    }
}

// MARK: - Helper Functions

private func waitForStatus(_ database: Database, expectedStatus: DatabaseStatus) async throws {
    let timeout: UInt64 = 5_000_000_000 // 5 seconds in nanoseconds
    let interval: UInt64 = 100_000_000 // 100ms check interval
    var elapsed: UInt64 = 0

    while elapsed < timeout {
        let currentStatus = await database.status
        if currentStatus == expectedStatus {
            return
        }
        try await Task.sleep(nanoseconds: interval)
        elapsed += interval
    }

    throw DatabaseError.timeout
}
