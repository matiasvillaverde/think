import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
@testable import Database
import Foundation
import Testing
import Tools

/// Acceptance test demonstrating the complete agentic loop with minimal mocking
/// Only mocks LLMSession; uses real Database, ContextBuilder, ToolManager
@Suite("Agentic Loop Acceptance", .tags(.acceptance))
internal struct AgenticLoopAcceptanceTests {
    @Test("Complete Agentic Loop with Health Data Tool")
    @MainActor
    internal func testCompleteAgenticLoopWithHealthTool() async throws {
        let env: TestEnvironment = try await setupHealthEnvironment()
        await configureHealthToolPattern(env.mlxSession)

        try await executeHealthGeneration(env)

        try await verifyHealthFlow(
            database: env.database,
            chatId: env.chatId,
            healthTool: env.healthTool
        )
    }

    // MARK: - Setup Helpers

    @MainActor
    private func setupHealthEnvironment() async throws -> TestEnvironment {
        let database: Database = try await createDatabase()
        let chatId: UUID = try await setupChat(database)
        let (toolManager, healthTool): (ToolManager, TestHealthStrategy) = await setupHealthTooling()
        let mlxSession: MockLLMSession = MockLLMSession()
        let orchestrator: AgentOrchestrator = createOrchestrator(
            database: database,
            mlxSession: mlxSession,
            toolManager: toolManager
        )

        return TestEnvironment(
            database: database,
            chatId: chatId,
            orchestrator: orchestrator,
            mlxSession: mlxSession,
            healthTool: healthTool
        )
    }

    private func setupHealthTooling() async -> (ToolManager, TestHealthStrategy) {
        let healthTool: TestHealthStrategy = TestHealthStrategy()
        let toolManager: ToolManager = ToolManager()
        await toolManager.registerStrategy(healthTool)
        return (toolManager, healthTool)
    }

    @MainActor
    private func createDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database: Database = try Database.new(configuration: config)
        try await AgentOrchestratorTestHelpers.seedDatabase(database)
        return database
    }

    @MainActor
    private func setupChat(_ database: Database) async throws -> UUID {
        let model: ModelDTO = createHarmonyModel()
        try await database.write(
            ModelCommands.AddModels(modelDTOs: [model])
        )
        return try await createChatWithModel(database)
    }

    private func createHarmonyModel() -> ModelDTO {
        ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-harmony",
            displayName: "Test Harmony",
            displayDescription: "Test model",
            skills: ["text-generation", "tool-use"],
            parameters: 1_000_000_000,
            ramNeeded: 2_097_152,
            size: 1_048_576,
            locationHuggingface: "test/harmony",
            version: 1,
            architecture: .harmony
        )
    }

    private func createChatWithModel(_ database: Database) async throws -> UUID {
        let personalityId: UUID = try await database.read(
            PersonalityCommands.GetDefault()
        )

        let models: [SendableModel] = try await database.read(
            ModelCommands.FetchAll()
        )

        guard let foundModel = models.first else {
            throw DatabaseError.modelNotFound
        }

        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: foundModel.id,
                personalityId: personalityId
            )
        )
    }

    private func createOrchestrator(
        database: Database,
        mlxSession: MockLLMSession,
        toolManager: ToolManager
    ) -> AgentOrchestrator {
        let mockDownloader: MockModelDownloader = createConfiguredDownloader()
        let coordinator: ModelStateCoordinator = createCoordinator(
            database: database,
            mlxSession: mlxSession,
            mockDownloader: mockDownloader
        )

        let persistor: MessagePersistor = MessagePersistor(database: database)
        let contextBuilder: ContextBuilder = ContextBuilder(tooling: toolManager)

        return AgentOrchestrator(
            modelCoordinator: coordinator,
            persistor: persistor,
            contextBuilder: contextBuilder,
            tooling: toolManager
        )
    }

    private func createConfiguredDownloader() -> MockModelDownloader {
        let mockDownloader: MockModelDownloader = MockModelDownloader()
        mockDownloader.configureForStandardTests()
        // Add test/harmony as a downloaded model
        mockDownloader.configureModel(
            for: "test/harmony",
            location: URL(fileURLWithPath: "/tmp/models/test_harmony"),
            exists: true,
            size: 1_048_576
        )
        return mockDownloader
    }

    private func createCoordinator(
        database: Database,
        mlxSession: MockLLMSession,
        mockDownloader: MockModelDownloader
    ) -> ModelStateCoordinator {
        ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: mockDownloader
        )
    }

    // MARK: - Test Execution

    private func executeHealthGeneration(_ env: TestEnvironment) async throws {
        try await env.orchestrator.load(chatId: env.chatId)

        try await env.orchestrator.generate(
            prompt: "How many steps did I walk yesterday?",
            action: .textGeneration([])
        )
    }

    private func configureHealthToolPattern(_ session: MockLLMSession) async {
        let firstResponse: MockLLMSession.MockStreamResponse = .text([
            "<|channel|>commentary<|message|>" +
            "I'll check your step count from yesterday's health data." +
            "<|end|>",
            "<|channel|>tool<|message|>" +
            "{\"metric\": \"steps\", \"date\": \"yesterday\"}" +
            "<|recipient|>health_data<|call|>"
        ], delayBetweenChunks: 0.001)

        let finalResponse: MockLLMSession.MockStreamResponse = .text([
            "<|channel|>final<|message|>" +
            "According to your health data, you walked 8,543 steps yesterday!" +
            "<|end|>"
        ], delayBetweenChunks: 0.001)

        await session.setSequentialStreamResponses([
            firstResponse,
            finalResponse
        ])
    }

    // MARK: - Verification

    private func verifyHealthFlow(
        database: Database,
        chatId: UUID,
        healthTool: TestHealthStrategy
    ) async throws {
        try verifyHealthToolExecution(healthTool)
        try await verifyHealthMessageStructure(database: database, chatId: chatId)
    }

    private func verifyHealthToolExecution(_ healthTool: TestHealthStrategy) throws {
        try AgenticLoopVerificationHelpers.verifyHealthToolExecution(healthTool)
    }

    @MainActor
    private func verifyHealthMessageStructure(
        database: Database,
        chatId: UUID
    ) async throws {
        try await AgenticLoopVerificationHelpers.verifyHealthMessageStructure(
            database: database,
            chatId: chatId
        )
    }

    // MARK: - Test Environment

    private struct TestEnvironment {
        let database: Database
        let chatId: UUID
        let orchestrator: AgentOrchestrator
        let mlxSession: MockLLMSession
        let healthTool: TestHealthStrategy
    }
}
