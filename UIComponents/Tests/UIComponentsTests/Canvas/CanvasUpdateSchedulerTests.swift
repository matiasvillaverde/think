import Abstractions
import AbstractionsTestUtilities
import Database
import Foundation
import Testing
@testable import UIComponents

@Suite("CanvasUpdateScheduler Tests")
@MainActor
internal struct CanvasUpdateSchedulerTests {
    private func createTestDatabase() throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        return try Database.new(configuration: config)
    }

    @Test("Scheduled update persists after debounce")
    @MainActor
    func scheduledUpdatePersistsAfterDebounce() async throws {
        let database: Database = try createTestDatabase()
        let canvasId: UUID = try await database.write(
            CanvasCommands.Create(
                title: "Draft",
                content: "Original",
                chatId: nil
            )
        )

        let scheduler: CanvasUpdateScheduler = CanvasUpdateScheduler(
            debounceNanoseconds: 50_000_000
        )

        await scheduler.scheduleUpdate(
            database: database,
            canvasId: canvasId,
            title: "Updated",
            content: "Updated content"
        )

        try await Task.sleep(nanoseconds: 150_000_000)

        let canvas: CanvasDocument = try await database.read(
            CanvasCommands.Get(id: canvasId)
        )

        #expect(canvas.title == "Updated")
        #expect(canvas.content == "Updated content")
    }

    @Test("Flush persists latest draft and cancels pending update")
    @MainActor
    func flushPersistsLatestDraft() async throws {
        let database: Database = try createTestDatabase()
        let canvasId: UUID = try await database.write(
            CanvasCommands.Create(
                title: "Draft",
                content: "Original",
                chatId: nil
            )
        )

        let scheduler: CanvasUpdateScheduler = CanvasUpdateScheduler(
            debounceNanoseconds: 200_000_000
        )

        await scheduler.scheduleUpdate(
            database: database,
            canvasId: canvasId,
            title: "Old",
            content: "Old content"
        )

        await scheduler.flush(
            database: database,
            canvasId: canvasId,
            title: "Newest",
            content: "Newest content"
        )

        try await Task.sleep(nanoseconds: 300_000_000)

        let canvas: CanvasDocument = try await database.read(
            CanvasCommands.Get(id: canvasId)
        )

        #expect(canvas.title == "Newest")
        #expect(canvas.content == "Newest content")
    }
}
