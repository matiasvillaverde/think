import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Stop Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorStopTests {
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

        return database
    }

    // MARK: - Tests

    @Test("Stop Without Active Session Does Nothing")
    @MainActor
    internal func stopWithoutActiveSessionDoesNothing() async throws {
        // Given - Coordinator with no loaded model
        let env: TestEnvironment = try await setupTestEnvironment()

        // Verify no model is loaded
        let initialMLXCalls: Int = await env.mlxSession.callCount(for: "stop")
        let initialGGUFCalls: Int = await env.ggufSession.callCount(for: "stop")
        #expect(initialMLXCalls == 0, "MLX session should have no stop calls initially")
        #expect(initialGGUFCalls == 0, "GGUF session should have no stop calls initially")

        // When - Stop is called without a session
        try await env.coordinator.stop()

        // Then - No session should be affected
        let afterMLXCalls: Int = await env.mlxSession.callCount(for: "stop")
        let afterGGUFCalls: Int = await env.ggufSession.callCount(for: "stop")
        #expect(afterMLXCalls == 0, "MLX session should not receive stop call")
        #expect(afterGGUFCalls == 0, "GGUF session should not receive stop call")

        // Verify no errors were thrown
        // If we got here, no error was thrown which is the expected behavior
    }

    @Test("Stop With Loaded Model But No Generation")
    @MainActor
    internal func stopWithLoadedModelButNoGeneration() async throws {
        // Given - Model is loaded but not generating
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Verify model is loaded
        #expect(await env.mlxSession.isModelLoaded, "Model should be loaded")
        #expect(await !env.mlxSession.isCurrentlyGenerating, "Should not be generating")

        // When - Stop is called
        try await env.coordinator.stop()

        // Then - Stop should be called on session
        await env.mlxSession.verifyStopCalled()

        // Model should still be loaded in coordinator
        #expect(await env.mlxSession.isModelLoaded, "Model should remain loaded after stop")
    }

    @Test("Stop During Active Generation")
    @MainActor
    internal func stopDuringActiveGeneration() async throws {
        // Given - Model is loaded and actively generating
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Start slow generation in background
        let streamTask: Task<[String], Error> = startSlowGeneration(env)

        // Give generation time to start
        try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        // When - Stop generation
        try await env.coordinator.stop()

        // Then - Verify stop was called
        await verifyStopWasCalled(env, streamTask: streamTask)
    }

    private func startSlowGeneration(_ env: TestEnvironment) -> Task<[String], Error> {
        // Configure slow generation
        let chunks: [String] = Array(repeating: "chunk", count: 100)
        Task {
            await env.mlxSession.configureForSuccessfulGeneration(texts: chunks, delay: 0.01)
        }

        // Start generation
        let input: LLMInput = createLLMInput()
        return Task {
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

    private func verifyStopWasCalled(_ env: TestEnvironment, streamTask: Task<[String], Error>) async {
        await env.mlxSession.verifyStopCalled()

        // Cancel and wait for task
        streamTask.cancel()
        _ = try? await streamTask.value

        // Verify stop was effective
        let stopCalls: Int = await env.mlxSession.callCount(for: "stop")
        #expect(stopCalls == 1, "Stop should be called exactly once")
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

    @MainActor
    private func getModelFromChat(_ database: Database, chatId: UUID) async throws -> SendableModel {
        try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))
    }

    private func createTestModel() -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model",
            displayName: "Test Model",
            displayDescription: "A test model for stop operations",
            skills: ["text-generation"],
            parameters: 1_000_000,
            ramNeeded: 100 * megabyte,
            size: 50 * megabyte,
            locationHuggingface: "test/model",
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
