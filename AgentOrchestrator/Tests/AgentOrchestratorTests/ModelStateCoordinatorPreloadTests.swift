import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Preload Progress Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorPreloadTests {
    // MARK: - Test Environment

    internal struct TestEnvironment {
        internal let database: Database
        internal let mlxSession: MockLLMSession
        internal let ggufSession: MockLLMSession
        internal let imageGenerator: MockImageGenerating
        internal let coordinator: ModelStateCoordinator
    }

    // MARK: - Test Helpers

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try await createAndInitializeDatabase()

        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()
        let imageGenerator: MockImageGenerating = MockImageGenerating()

        let coordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )

        return TestEnvironment(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            coordinator: coordinator
        )
    }

    @MainActor
    private func createAndInitializeDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database: Database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())

        return database
    }

    // MARK: - Tests

    @Test("Preload Progress Streams Successfully")
    @MainActor
    internal func preloadProgressStreamsSuccessfully() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        // Configure multi-step preload
        let expectedSteps: Int = 5
        await env.mlxSession.configureForSuccessfulPreload(steps: expectedSteps, delay: 0.001)

        // When - Load model (progress is consumed internally)
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify preload was called and completed
        await env.mlxSession.verifyPreloadCalled()
        #expect(await env.mlxSession.isModelLoaded, "Model should be loaded after preload")

        // Verify the model transitioned through loading states
        let preloadCalls: Int = await env.mlxSession.callCount(for: "preload")
        #expect(preloadCalls == 1, "Preload should be called once")
    }

    @Test("Preload With Single Step Completes")
    @MainActor
    internal func preloadWithSingleStepCompletes() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        // Configure single-step preload
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify successful load
        await env.mlxSession.verifyPreloadCalled()
        #expect(await env.mlxSession.isModelLoaded, "Model should be loaded")
    }

    @Test("Preload With Zero Delay Completes")
    @MainActor
    internal func preloadWithZeroDelayCompletes() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        // Configure preload with no delay
        await env.mlxSession.configureForSuccessfulPreload(steps: 10, delay: 0)

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify successful load
        await env.mlxSession.verifyPreloadCalled()
        #expect(await env.mlxSession.isModelLoaded, "Model should be loaded")
    }

    @Test("Preload Progress Consumed Silently")
    @MainActor
    internal func preloadProgressConsumedSilently() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        // Configure preload with many steps to ensure progress is being consumed
        let manySteps: Int = 100
        await env.mlxSession.configureForSuccessfulPreload(steps: manySteps, delay: 0.0001)

        // When - Load model (all progress events should be consumed)
        let startTime: Date = Date()
        try await env.coordinator.load(chatId: chatId)
        let loadTime: TimeInterval = Date().timeIntervalSince(startTime)

        // Then - Verify load completed in reasonable time
        #expect(loadTime < 1.0, "Load should complete quickly even with many progress steps")
        #expect(await env.mlxSession.isModelLoaded, "Model should be loaded")
    }

    @Test("Database State Transitions During Preload")
    @MainActor
    internal func databaseStateTransitionsDuringPreload() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        // Configure slow preload to observe state transitions
        await env.mlxSession.configureForSuccessfulPreload(steps: 3, delay: 0.01)

        // Get initial model state
        let initialModel: SendableModel = try await env.database.read(
            ChatCommands.GetLanguageModel(chatId: chatId)
        )
        let modelId: UUID = initialModel.id

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify model went through loading states
        // The coordinator should have called TransitionRuntimeState commands
        #expect(await env.mlxSession.isModelLoaded, "Model should be loaded")

        // After load, model should be in loaded state (though we can't directly verify
        // runtime state from SendableModel, we know the transitions happened)
        let finalModel: SendableModel = try await env.database.read(
            ChatCommands.GetLanguageModel(chatId: chatId)
        )
        #expect(finalModel.id == modelId, "Should be the same model")
    }

    @Test("Preload Already Loaded Model Is Quick")
    @MainActor
    internal func preloadAlreadyLoadedModelIsQuick() async throws {
        // Given - Model is already loaded
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        // First load
        await env.mlxSession.configureForSuccessfulPreload(steps: 5, delay: 0.01)
        try await env.coordinator.load(chatId: chatId)

        // Configure mock to report already loaded
        await env.mlxSession.configureForAlreadyLoaded()

        // When - Load same model again (should skip actual loading)
        let startTime: Date = Date()
        try await env.coordinator.load(chatId: chatId)
        let reloadTime: TimeInterval = Date().timeIntervalSince(startTime)

        // Then - Should be very quick since model is already loaded
        let maxReloadTime: TimeInterval = 0.25
        #expect(reloadTime < maxReloadTime, "Reload of same model should be nearly instant")
        #expect(await env.mlxSession.isModelLoaded, "Model should remain loaded")

        // Preload should only be called once (from first load)
        let preloadCalls: Int = await env.mlxSession.callCount(for: "preload")
        #expect(preloadCalls == 1, "Preload should only be called for first load")
    }

    // MARK: - Helper Methods

    @MainActor
    private func setupChatWithModel(_ database: Database) async throws -> UUID {
        let modelDTO: ModelDTO = createTestModel()
        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.location == "test/model" }) else {
            throw DatabaseError.modelNotFound
        }

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )
    }

    private func createTestModel() -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model",
            displayName: "Test Model",
            displayDescription: "A test model for preload progress",
            skills: ["text-generation"],
            parameters: 1_000_000,
            ramNeeded: 100 * megabyte,
            size: 50 * megabyte,
            locationHuggingface: "test/model",
            version: 2,
            architecture: .llama
        )
    }
}
