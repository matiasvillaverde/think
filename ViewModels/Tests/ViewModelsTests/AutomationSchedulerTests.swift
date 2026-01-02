import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("Automation Scheduler Tests")
internal struct AutomationSchedulerTests {
    @Test("Scheduler executes due schedule")
    @MainActor
    func schedulerExecutesDueSchedule() async throws {
        let database: Database = try await Self.makeDatabase()
        let chatId: UUID = try await Self.createChat(database: database)

        let past: Date = Date(timeIntervalSinceNow: -300)
        let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cronExpression: String = formatter.string(from: past)

        let scheduleId: UUID = try await database.write(
            AutomationScheduleCommands.Create(
                title: "Due",
                prompt: "Run task",
                scheduleKind: .oneShot,
                actionType: .text,
                cronExpression: cronExpression,
                isEnabled: true,
                chatId: chatId
            )
        )

        let orchestrator: MockAgentOrchestrator = MockAgentOrchestrator()
        let scheduler: AutomationScheduler = AutomationScheduler(
            database: database,
            orchestrator: orchestrator,
            pollInterval: 60
        )

        await scheduler.runOnce()

        let generateCalls: [(prompt: String, action: Action, timestamp: Date)] = await orchestrator.generateCalls
        #expect(generateCalls.count == 1)
        #expect(generateCalls.first?.prompt == "Run task")

        let schedule: AutomationSchedule = try await database.read(
            AutomationScheduleCommands.Get(id: scheduleId)
        )
        #expect(schedule.lastRunAt != nil)
        #expect(schedule.isRunning == false)
    }

    private static func makeDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database: Database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        try await addRequiredModels(database)
        return database
    }

    private static func createChat(database: Database) async throws -> UUID {
        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let languageModel: SendableModel = models.first(where: { isLanguageCapable($0.modelType) }) else {
            throw DatabaseError.modelNotFound
        }
        return try await database.write(
            ChatCommands.CreateWithModel(modelId: languageModel.id, personalityId: personalityId)
        )
    }

    private static func isLanguageCapable(_ type: SendableModel.ModelType) -> Bool {
        switch type {
        case .language, .visualLanguage, .deepLanguage, .flexibleThinker:
            return true

        case .diffusion, .diffusionXL:
            return false
        }
    }

    private static func addRequiredModels(_ database: Database) async throws {
        try await database.write(PersonalityCommands.WriteDefault())

        let languageModel: ModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-llm",
            displayName: "Test LLM",
            displayDescription: "Test language model",
            skills: ["text-generation"],
            parameters: 1_000,
            ramNeeded: 64,
            size: 128,
            locationHuggingface: "test/llm",
            version: 1
        )

        let imageModel: ModelDTO = ModelDTO(
            type: .diffusion,
            backend: .mlx,
            name: "test-image",
            displayName: "Test Image",
            displayDescription: "Test image model",
            skills: ["image-generation"],
            parameters: 1_000,
            ramNeeded: 64,
            size: 128,
            locationHuggingface: "test/image",
            version: 1
        )

        try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
    }
}
