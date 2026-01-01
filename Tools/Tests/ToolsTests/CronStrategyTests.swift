import Abstractions
import AbstractionsTestUtilities
import Foundation
import Testing
@testable import Database
@testable import Tools

@Suite("Cron Strategy Tests")
struct CronStrategyTests {
    @Test("Create schedule via tool")
    @MainActor
    func createScheduleViaTool() async throws {
        let database = try await Self.makeDatabase()
        let strategy = CronStrategy(database: database)

        let request = ToolRequest(
            name: "cron",
            arguments: """
            {"action":"create","prompt":"Ping","cron":"*/5 * * * *"}
            """,
            context: ToolRequestContext(chatId: nil, messageId: nil)
        )

        let response = await strategy.execute(request: request)
        #expect(response.error == nil)

        let schedules = try await database.read(AutomationScheduleCommands.List())
        #expect(schedules.count == 1)
        #expect(schedules.first?.prompt == "Ping")
    }

    @Test("List schedules via tool")
    @MainActor
    func listSchedulesViaTool() async throws {
        let database = try await Self.makeDatabase()
        _ = try await database.write(
            AutomationScheduleCommands.Create(
                title: "Test",
                prompt: "Ping",
                scheduleKind: .cron,
                actionType: .text,
                cronExpression: "0 * * * *",
                chatId: nil
            )
        )

        let strategy = CronStrategy(database: database)
        let request = ToolRequest(
            name: "cron",
            arguments: "{\"action\":\"list\"}",
            context: ToolRequestContext(chatId: nil, messageId: nil)
        )

        let response = await strategy.execute(request: request)
        #expect(response.error == nil)
        #expect(response.result.contains("Ping"))
    }

    private static func makeDatabase() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        return database
    }
}
