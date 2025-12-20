import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Acceptance Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorAcceptanceTests {
    // MARK: - Test Environment

    internal struct TestEnvironment {
        internal let database: Database
        internal let mlxSession: MockLLMSession
        internal let imageGenerator: MockImageGenerating
        internal let coordinator: ModelStateCoordinator
        internal let chatId: UUID
    }

    // MARK: - Test Helpers

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try await createAndInitializeDatabase()
        let chatId: UUID = try await createChat(database)

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
            imageGenerator: imageGenerator,
            coordinator: coordinator,
            chatId: chatId
        )
    }

    @MainActor
    private func createAndInitializeDatabase() async throws -> Database {
        // Create in-memory database
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database: Database = try Database.new(configuration: config)

        // Initialize app (creates user and default models)
        _ = try await database.execute(AppCommands.Initialize())

        // Add language models that ModelStateCoordinator can use
        try await addLanguageModels(database)

        return database
    }

    @MainActor
    private func addLanguageModels(_ database: Database) async throws {
        let languageModel: ModelDTO = createTestLanguageModel()
        let imageModel: ModelDTO = createTestImageModel()
        try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
    }

    private func createTestLanguageModel() -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-mlx-llm",
            displayName: "Test MLX LLM",
            displayDescription: "A test MLX language model",
            skills: ["text-generation"],
            parameters: 1_000_000,
            ramNeeded: 100 * megabyte,
            size: 50 * megabyte,
            locationHuggingface: "test/mlx-llm",
            version: 2,
            architecture: .llama
        )
    }

    private func createTestImageModel() -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "test-image-model",
            displayName: "Test Image Model",
            displayDescription: "A test image generation model",
            skills: ["image-generation"],
            parameters: 500_000,
            ramNeeded: 200 * megabyte,
            size: 100 * megabyte,
            locationHuggingface: "test/image-model",
            version: 2,
            architecture: .stableDiffusion
        )
    }

    @MainActor
    private func createChat(_ database: Database) async throws -> UUID {
        // Get the default personality (created during app initialization)
        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())

        // Get a language model to use for the chat
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())

        var languageModel: SendableModel?
        for model in models where model.location == "test/mlx-llm" {
            languageModel = model
            break
        }

        guard let model = languageModel else {
            throw DatabaseError.modelNotFound
        }

        // Create chat with specific model
        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
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

    private func performGeneration(
        coordinator: ModelStateCoordinator,
        input: LLMInput
    ) async throws -> [String] {
        var receivedChunks: [String] = []
        for try await chunk in await coordinator.stream(input) {
            receivedChunks.append(chunk.text)
        }
        return receivedChunks
    }

    // MARK: - Tests

    // MARK: - Helper Methods for Tests

    @Test("Load and Generate Text Successfully")
    @MainActor
    internal func loadAndGenerateTextSuccessfully() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        await env.mlxSession.configureForSuccessfulPreload(steps: 3, delay: 0.001)

        // Configure mock session for successful generation
        let expectedChunks: [String] = ["Hello", " world", "!"]
        await env.mlxSession.configureForSuccessfulGeneration(texts: expectedChunks, delay: 0.001)

        // Verify we can get the model from the chat
        let model: SendableModel = try await env.database.read(
            ChatCommands.GetLanguageModel(chatId: env.chatId)
        )
        #expect(model.location == "test/mlx-llm", "Should have correct model")

        // When - Load model
        try await env.coordinator.load(chatId: env.chatId)
        await env.mlxSession.verifyPreloadCalled()
        #expect(await env.mlxSession.isModelLoaded, "Session should report model as loaded")

        // When - Generate text
        let input: LLMInput = createLLMInput()
        let receivedChunks: [String] = try await performGeneration(
            coordinator: env.coordinator,
            input: input
        )

        // Then - Verify generation worked
        #expect(receivedChunks == expectedChunks, "Should receive all chunks in order")
        await env.mlxSession.verifyStreamCalled(with: "Test prompt")
    }

    @Test("Load Same Model Twice Should Skip Second Load")
    @MainActor
    internal func loadSameModelTwice() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        await env.mlxSession.configureForSuccessfulPreload(steps: 3, delay: 0.001)

        // When - Load model first time
        try await env.coordinator.load(chatId: env.chatId)

        // Verify preload was called once
        let firstCallCount: Int = await env.mlxSession.callCount(for: "preload")
        #expect(firstCallCount == 1, "Preload should be called once")

        // When - Load same model again
        try await env.coordinator.load(chatId: env.chatId)

        // Then - Verify preload was NOT called again
        let secondCallCount: Int = await env.mlxSession.callCount(for: "preload")
        #expect(secondCallCount == 1, "Preload should not be called again for same model")
    }

    private func createStreamTask(
        _ env: TestEnvironment,
        _ input: LLMInput
    ) -> Task<[String], Error> {
        Task {
            var received: [String] = []
            do {
                for try await chunk in await env.coordinator.stream(input) {
                    received.append(chunk.text)
                }
            } catch {
                // Expected cancellation
            }
            return received
        }
    }

    @Test("Stop Generation Updates Model State")
    @MainActor
    internal func stopGenerationUpdatesState() async throws {
        // Given - Model is loaded and generating
        let env: TestEnvironment = try await setupTestEnvironment()
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // Configure slow generation
        let chunks: [String] = ["Chunk1", "Chunk2", "Chunk3"]
        await env.mlxSession.configureForSuccessfulGeneration(texts: chunks, delay: 0.1)

        // Load model
        try await env.coordinator.load(chatId: env.chatId)

        // Start generation in background
        let input: LLMInput = createLLMInput()
        let streamTask: Task<[String], Error> = createStreamTask(env, input)

        // Give generation time to start
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        // When - Stop generation
        try await env.coordinator.stop()

        // Then - Verify stop was called on session
        await env.mlxSession.verifyStopCalled()

        // Cancel the stream task
        streamTask.cancel()
        _ = try? await streamTask.value
    }

    @Test("Unload Model Clears State")
    @MainActor
    internal func unloadModelClearsState() async throws {
        // Given - Model is loaded
        let env: TestEnvironment = try await setupTestEnvironment()
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: env.chatId)

        // Verify model is loaded in session
        #expect(await env.mlxSession.isModelLoaded, "Model should be loaded")

        // When - Unload model
        try await env.coordinator.unload()

        // Then - Verify unload was called on session
        await env.mlxSession.verifyUnloadCalled()

        // Verify model is unloaded in session
        #expect(await env.mlxSession.isModelLoaded == false, "Model should be unloaded")
    }
}
