import Abstractions
import AbstractionsTestUtilities
import Foundation
import Testing
@testable import Database

@Suite("Automation Schedule Commands Tests")
struct AutomationScheduleCommandsTests {
    @Test("Create cron schedule computes next run")
    @MainActor
    func createCronScheduleComputesNextRun() async throws {
        let database = try await Self.makeDatabase()
        let chatId = try await Self.createChat(database: database)

        let scheduleId = try await database.write(
            AutomationScheduleCommands.Create(
                title: "Hourly",
                prompt: "Ping",
                scheduleKind: .cron,
                actionType: .text,
                cronExpression: "0 * * * *",
                timezoneIdentifier: "UTC",
                toolNames: [],
                isEnabled: true,
                chatId: chatId
            )
        )

        let schedule = try await database.read(
            AutomationScheduleCommands.Get(id: scheduleId)
        )

        #expect(schedule.nextRunAt != nil)
        if let nextRunAt = schedule.nextRunAt {
            let calendar = Calendar(identifier: .gregorian).withTimeZone(identifier: "UTC")
            let minute = calendar.component(.minute, from: nextRunAt)
            #expect(minute == 0)
            #expect(nextRunAt >= schedule.createdAt)
        }
    }

    @Test("FetchDue returns past one-shot schedule")
    @MainActor
    func fetchDueReturnsOneShot() async throws {
        let database = try await Self.makeDatabase()
        let chatId = try await Self.createChat(database: database)

        let past = Date(timeIntervalSinceNow: -120)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cronExpression = formatter.string(from: past)

        let scheduleId = try await database.write(
            AutomationScheduleCommands.Create(
                title: "OneShot",
                prompt: "Do it",
                scheduleKind: .oneShot,
                actionType: .text,
                cronExpression: cronExpression,
                isEnabled: true,
                chatId: chatId
            )
        )

        let due = try await database.read(
            AutomationScheduleCommands.FetchDue(now: Date())
        )

        #expect(due.contains { $0.id == scheduleId })
    }

    @Test("MarkCompleted disables one-shot schedule")
    @MainActor
    func markCompletedDisablesOneShot() async throws {
        let database = try await Self.makeDatabase()
        let chatId = try await Self.createChat(database: database)

        let future = Date(timeIntervalSinceNow: 600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cronExpression = formatter.string(from: future)

        let scheduleId = try await database.write(
            AutomationScheduleCommands.Create(
                title: "OneShot",
                prompt: "Finish",
                scheduleKind: .oneShot,
                actionType: .text,
                cronExpression: cronExpression,
                isEnabled: true,
                chatId: chatId
            )
        )

        _ = try await database.write(
            AutomationScheduleCommands.MarkCompleted(id: scheduleId, finishedAt: Date())
        )

        let schedule = try await database.read(
            AutomationScheduleCommands.Get(id: scheduleId)
        )

        #expect(schedule.isEnabled == false)
        #expect(schedule.nextRunAt == nil)
        #expect(schedule.lastRunAt != nil)
    }

    private static func makeDatabase() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        try await addRequiredModelsForChatCommands(database)
        return database
    }

    private static func createChat(database: Database) async throws -> UUID {
        let personalityId = try await database.read(PersonalityCommands.GetDefault())
        let models = try await database.read(ModelCommands.FetchAll())
        guard let languageModel = models.first(where: { $0.modelType.isLanguageCapable }) else {
            throw DatabaseError.modelNotFound
        }
        return try await database.write(
            ChatCommands.CreateWithModel(modelId: languageModel.id, personalityId: personalityId)
        )
    }
}

private extension Calendar {
    func withTimeZone(identifier: String?) -> Calendar {
        guard let identifier,
              let timeZone = TimeZone(identifier: identifier) else {
            return self
        }
        var copy = self
        copy.timeZone = timeZone
        return copy
    }
}
