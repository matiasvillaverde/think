import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Switching Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorSwitchingTests {
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
        try await AgentOrchestratorTestHelpers.seedDatabase(database)

        // Add multiple models for switching tests
        try await addMultipleModels(database)

        return database
    }

    @MainActor
    private func addMultipleModels(_ database: Database) async throws {
        let model1: ModelDTO = createTestModel(name: "model-1", location: "test/model-1", backend: .mlx)
        let model2: ModelDTO = createTestModel(name: "model-2", location: "test/model-2", backend: .mlx)
        let model3: ModelDTO = createTestModel(name: "model-3", location: "test/model-3", backend: .gguf)
        try await database.write(ModelCommands.AddModels(modelDTOs: [model1, model2, model3]))
    }

    // MARK: - Tests

    @Test("Switch Between Different MLX Models")
    @MainActor
    internal func switchBetweenDifferentMLXModels() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId1: UUID = try await createChatWithModel(env.database, location: "test/model-1")
        let chatId2: UUID = try await createChatWithModel(env.database, location: "test/model-2")

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load first model
        try await env.coordinator.load(chatId: chatId1)
        let firstUnloadCount: Int = await env.mlxSession.callCount(for: "unload")
        #expect(firstUnloadCount == 0, "Should not unload on first load")

        // When - Switch to second model
        try await env.coordinator.load(chatId: chatId2)

        // Then - First model should be unloaded, second model loaded
        let unloadCount: Int = await env.mlxSession.callCount(for: "unload")
        #expect(unloadCount == 1, "Should unload previous model")

        let preloadCount: Int = await env.mlxSession.callCount(for: "preload")
        #expect(preloadCount == 2, "Should preload both models")

        #expect(await env.mlxSession.isModelLoaded, "Second model should be loaded")
    }

    @Test("Switch From MLX to GGUF Model")
    @MainActor
    internal func switchFromMLXToGGUFModel() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let mlxChatId: UUID = try await createChatWithModel(env.database, location: "test/model-1")
        let ggufChatId: UUID = try await createChatWithModel(env.database, location: "test/model-3")

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        await env.ggufSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load MLX model first
        try await env.coordinator.load(chatId: mlxChatId)
        #expect(await env.mlxSession.isModelLoaded, "MLX model should be loaded")

        // When - Switch to GGUF model
        try await env.coordinator.load(chatId: ggufChatId)

        // Then - MLX model should be unloaded, GGUF model loaded
        await env.mlxSession.verifyUnloadCalled()
        #expect(await !env.mlxSession.isModelLoaded, "MLX model should be unloaded")

        await env.ggufSession.verifyPreloadCalled()
        #expect(await env.ggufSession.isModelLoaded, "GGUF model should be loaded")
    }

    @Test("Switch Back to Previously Loaded Model")
    @MainActor
    internal func switchBackToPreviouslyLoadedModel() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId1: UUID = try await createChatWithModel(env.database, location: "test/model-1")
        let chatId2: UUID = try await createChatWithModel(env.database, location: "test/model-2")

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model 1, then model 2, then back to model 1
        try await env.coordinator.load(chatId: chatId1)
        try await env.coordinator.load(chatId: chatId2)
        try await env.coordinator.load(chatId: chatId1)

        // Then - Should have unloaded twice and preloaded three times
        let unloadCount: Int = await env.mlxSession.callCount(for: "unload")
        #expect(unloadCount == 2, "Should unload twice when switching")

        let preloadCount: Int = await env.mlxSession.callCount(for: "preload")
        #expect(preloadCount == 3, "Should preload three times total")
    }

    @Test("Rapid Model Switching Handles Correctly")
    @MainActor
    internal func rapidModelSwitchingHandlesCorrectly() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId1: UUID = try await createChatWithModel(env.database, location: "test/model-1")
        let chatId2: UUID = try await createChatWithModel(env.database, location: "test/model-2")

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Rapidly switch between models
        for _ in 1...5 {
            try await env.coordinator.load(chatId: chatId1)
            try await env.coordinator.load(chatId: chatId2)
        }

        // Then - Should handle all switches correctly
        let unloadCount: Int = await env.mlxSession.callCount(for: "unload")
        #expect(unloadCount == 9, "Should unload 9 times (all switches except first load)")

        let preloadCount: Int = await env.mlxSession.callCount(for: "preload")
        #expect(preloadCount == 10, "Should preload 10 times (5 times each model)")

        #expect(await env.mlxSession.isModelLoaded, "Final model should be loaded")
    }

    @Test("Stream After Model Switch Uses New Model")
    @MainActor
    internal func streamAfterModelSwitchUsesNewModel() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId1: UUID = try await createChatWithModel(env.database, location: "test/model-1")
        let chatId2: UUID = try await createChatWithModel(env.database, location: "test/model-2")

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // Load first model
        try await env.coordinator.load(chatId: chatId1)

        // Configure different responses for tracking
        await env.mlxSession.configureForSuccessfulGeneration(texts: ["Model", " Two"], delay: 0.001)

        // When - Switch to second model and stream
        try await env.coordinator.load(chatId: chatId2)

        let input: LLMInput = createLLMInput()
        var receivedChunks: [String] = []
        for try await chunk in await env.coordinator.stream(input) {
            receivedChunks.append(chunk.text)
        }

        // Then - Should receive chunks from the session
        #expect(receivedChunks == ["Model", " Two"], "Should stream from new model")
        await env.mlxSession.verifyStreamCalled()
    }

    @Test("Unload After Switching Models")
    @MainActor
    internal func unloadAfterSwitchingModels() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId1: UUID = try await createChatWithModel(env.database, location: "test/model-1")
        let chatId2: UUID = try await createChatWithModel(env.database, location: "test/model-2")

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load models and switch, then unload
        try await env.coordinator.load(chatId: chatId1)
        try await env.coordinator.load(chatId: chatId2)
        try await env.coordinator.unload()

        // Then - All models should be unloaded
        let unloadCount: Int = await env.mlxSession.callCount(for: "unload")
        #expect(unloadCount == 2, "Should unload twice (once for switch, once for explicit unload)")

        #expect(await !env.mlxSession.isModelLoaded, "No model should be loaded")
        #expect(await !env.ggufSession.isModelLoaded, "GGUF session should also be unloaded")
    }

    @Test("Session Switching Verifies Correct Backend Usage")
    @MainActor
    internal func testSessionSwitchingVerifiesCorrectBackendUsage() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let mlxChatId: UUID = try await createChatWithModel(env.database, location: "test/model-1")
        let ggufChatId: UUID = try await createChatWithModel(env.database, location: "test/model-3")

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        await env.ggufSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load MLX model
        try await env.coordinator.load(chatId: mlxChatId)

        // Then - Only MLX session should be used
        let mlxPreloadCount: Int = await env.mlxSession.callCount(for: "preload")
        let ggufPreloadCount: Int = await env.ggufSession.callCount(for: "preload")
        #expect(mlxPreloadCount == 1, "MLX session should be preloaded")
        #expect(ggufPreloadCount == 0, "GGUF session should not be touched")

        // When - Switch to GGUF model
        try await env.coordinator.load(chatId: ggufChatId)

        // Then - MLX should be unloaded, GGUF should be loaded
        let mlxUnloadCount: Int = await env.mlxSession.callCount(for: "unload")
        let ggufPreloadAfterSwitch: Int = await env.ggufSession.callCount(for: "preload")
        #expect(mlxUnloadCount == 1, "MLX session should be unloaded")
        #expect(ggufPreloadAfterSwitch == 1, "GGUF session should now be preloaded")

        // When - Switch back to MLX model
        try await env.coordinator.load(chatId: mlxChatId)

        // Then - GGUF should be unloaded, MLX should be reloaded
        let ggufUnloadCount: Int = await env.ggufSession.callCount(for: "unload")
        let mlxPreloadFinal: Int = await env.mlxSession.callCount(for: "preload")
        #expect(ggufUnloadCount == 1, "GGUF session should be unloaded")
        #expect(mlxPreloadFinal == 2, "MLX session should be preloaded again")
    }

    @Test("Concurrent Session Switches Handle Correctly")
    @MainActor
    internal func testConcurrentSessionSwitchesHandleCorrectly() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let mlxChatId: UUID = try await createChatWithModel(env.database, location: "test/model-2")
        let ggufChatId: UUID = try await createChatWithModel(env.database, location: "test/model-3")

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        await env.ggufSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Perform rapid switches between MLX and GGUF
        for iteration in 1...3 {
            if iteration.isMultiple(of: 2) {
                try await env.coordinator.load(chatId: ggufChatId)
            } else {
                try await env.coordinator.load(chatId: mlxChatId)
            }
        }

        // Then - Verify correct session management
        let mlxUnloadCount: Int = await env.mlxSession.callCount(for: "unload")
        let ggufUnloadCount: Int = await env.ggufSession.callCount(for: "unload")

        // MLX loads at iterations 1, 3; unloads at iteration 2
        #expect(mlxUnloadCount == 1, "MLX should be unloaded once")
        // GGUF loads at iteration 2; unloads at iteration 3
        #expect(ggufUnloadCount == 1, "GGUF should be unloaded once")

        // Final state should be MLX loaded (iteration 3)
        #expect(await env.mlxSession.isModelLoaded, "MLX should be loaded at end")
        #expect(await !env.ggufSession.isModelLoaded, "GGUF should not be loaded at end")
    }

    // MARK: - Helper Methods

    @MainActor
    private func createChatWithModel(
        _ database: Database,
        location: String
    ) async throws -> UUID {
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.location == location }) else {
            throw DatabaseError.modelNotFound
        }

        let personalityId: UUID = try await database.write(
            TestPersonalityCommands.CreateChatGPTTestPersonality(
                currentDateOverride: UUID().uuidString
            )
        )
        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )
    }

    private func createTestModel(
        name: String,
        location: String,
        backend: SendableModel.Backend
    ) -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: backend,
            name: name,
            displayName: "Test \(name)",
            displayDescription: "A test model for switching",
            skills: ["text-generation"],
            parameters: 1_000_000,
            ramNeeded: 100 * megabyte,
            size: 50 * megabyte,
            locationHuggingface: location,
            version: 2,
            architecture: .llama
        )
    }

    private func createLLMInput() -> LLMInput {
        LLMInput(
            context: "Test prompt",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                topK: 40,
                repetitionPenalty: 1.1,
                frequencyPenalty: 0.0,
                presencePenalty: 0.0,
                repetitionPenaltyRange: 64,
                seed: nil,
                stopSequences: []
            ),
            limits: ResourceLimits(maxTokens: 100)
        )
    }
}
