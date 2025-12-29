import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import Database
import Foundation

internal struct ComplexTestEnvironment {
    private enum Constants {
        static let chunkDelay: TimeInterval = 0.001
    }

    internal let database: Database
    internal let orchestrator: AgentOrchestrator
    internal let mockSession: MockLLMSession
    internal let chatId: UUID

    internal static func create() async throws -> Self {
        let database: Database = try await createDatabase()
        let chatId: UUID = try await setupChat(database)
        let (orchestrator, mockSession): (AgentOrchestrator, MockLLMSession) =
            try await createOrchestrator(database: database)

        return createTestEnvironment(
            database: database,
            orchestrator: orchestrator,
            mockSession: mockSession,
            chatId: chatId
        )
    }

    private static func createDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database: Database = try Database.new(configuration: config)
        try await ComplexModelFactory.addComplexModels(database)
        return database
    }

    private static func createOrchestrator(
        database: Database
    ) async throws -> (AgentOrchestrator, MockLLMSession) {
        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.modelType == .language }) else {
            throw ComplexTestError.modelNotFound
        }

        let chatId: UUID = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )

        let (orchestrator, mockSession): (AgentOrchestrator, MockLLMSession) =
            await ComplexOrchestratorFactory.createOrchestratorWithMocks(database: database)

        try await orchestrator.load(chatId: chatId)
        return (orchestrator, mockSession)
    }

    private static func createTestEnvironment(
        database: Database,
        orchestrator: AgentOrchestrator,
        mockSession: MockLLMSession,
        chatId: UUID
    ) -> Self {
        Self(
            database: database,
            orchestrator: orchestrator,
            mockSession: mockSession,
            chatId: chatId
        )
    }

    @MainActor
    private static func setupChat(_ database: Database) async throws -> UUID {
        try await ComplexModelFactory.addComplexModels(database)
        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.modelType == .language }) else {
            throw ComplexTestError.modelNotFound
        }

        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )
    }

    internal func configureComplexTravelFlow() async {
        await mockSession.setSequentialStreamResponses(createComplexResponses())
    }

    private func createComplexResponses() -> [MockLLMSession.MockStreamResponse] {
        createMockResponses()
    }

    private func createMockResponses() -> [MockLLMSession.MockStreamResponse] {
        createWeatherResponse() + createLocationResponse() + createCalculatorResponse() +
        createCalendarResponse() + createNewsResponse() + createFinalResponse()
    }

    private func createWeatherResponse() -> [MockLLMSession.MockStreamResponse] {
        [
            .text([
                "<|channel|>commentary<|message|>Checking weather for Paris<|recipient|>weather<|end|>",
                "<|channel|>tool<|message|>{\"location\":\"Paris\"}<|recipient|>weather<|call|>"
            ], delayBetweenChunks: Constants.chunkDelay)
        ]
    }

    private func createLocationResponse() -> [MockLLMSession.MockStreamResponse] {
        [
            .text([
                "<|channel|>commentary<|message|>Finding attractions<|recipient|>location<|end|>",
                "<|channel|>tool<|message|>{\"city\":\"Paris\"}<|recipient|>location<|call|>"
            ], delayBetweenChunks: Constants.chunkDelay)
        ]
    }

    private func createCalculatorResponse() -> [MockLLMSession.MockStreamResponse] {
        [
            .text([
                "<|channel|>commentary<|message|>Calculating budget<|recipient|>calculator<|end|>",
                "<|channel|>tool<|message|>{\"expression\":\"500+130\"}<|recipient|>calculator<|call|>"
            ], delayBetweenChunks: Constants.chunkDelay)
        ]
    }

    private func createCalendarResponse() -> [MockLLMSession.MockStreamResponse] {
        [
            .text([
                "<|channel|>commentary<|message|>Checking schedules<|recipient|>calendar<|end|>",
                "<|channel|>tool<|message|>{\"date\":\"2026-06-01\"}<|recipient|>calendar<|call|>"
            ], delayBetweenChunks: Constants.chunkDelay)
        ]
    }

    private func createNewsResponse() -> [MockLLMSession.MockStreamResponse] {
        [
            .text([
                "<|channel|>commentary<|message|>Checking events<|recipient|>news<|end|>",
                "<|channel|>tool<|message|>{\"topic\":\"Paris\"}<|recipient|>news<|call|>"
            ], delayBetweenChunks: Constants.chunkDelay)
        ]
    }

    private func createFinalResponse() -> [MockLLMSession.MockStreamResponse] {
        [
            .text([
                "<|channel|>commentary<|message|>Creating final plan<|end|>",
                "<|channel|>final<|message|>Paris trip plan: Weather sunny, Budget €630, complete<|end|>"
            ], delayBetweenChunks: Constants.chunkDelay)
        ]
    }
}
