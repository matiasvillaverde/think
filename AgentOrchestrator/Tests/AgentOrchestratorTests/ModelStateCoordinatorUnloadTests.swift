import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Unload Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorUnloadTests {
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

    @Test("Unload Without Model Does Nothing")
    @MainActor
    internal func unloadWithoutModelDoesNothing() async throws {
        // Given - Coordinator with no loaded model
        let env: TestEnvironment = try await setupTestEnvironment()

        // Verify no model is loaded
        #expect(await !env.mlxSession.isModelLoaded, "MLX session should have no model loaded")
        #expect(await !env.ggufSession.isModelLoaded, "GGUF session should have no model loaded")

        // When - Unload is called without a model
        try await env.coordinator.unload()

        // Then - No session should be affected
        let mlxUnloadCalls: Int = await env.mlxSession.callCount(for: "unload")
        let ggufUnloadCalls: Int = await env.ggufSession.callCount(for: "unload")
        #expect(mlxUnloadCalls == 0, "MLX session should not receive unload call")
        #expect(ggufUnloadCalls == 0, "GGUF session should not receive unload call")

        // Verify state remains unchanged
        #expect(await !env.mlxSession.isModelLoaded, "MLX session should still have no model")
        #expect(await !env.ggufSession.isModelLoaded, "GGUF session should still have no model")
    }

    @Test("Unload After Loading Model")
    @MainActor
    internal func unloadAfterLoadingModel() async throws {
        // Given - Model is loaded
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Verify model is loaded
        #expect(await env.mlxSession.isModelLoaded, "Model should be loaded")

        // When - Unload is called
        try await env.coordinator.unload()

        // Then - Session should be unloaded
        await env.mlxSession.verifyUnloadCalled()
        #expect(await !env.mlxSession.isModelLoaded, "Model should be unloaded")

        // Verify only MLX session was affected (not GGUF)
        let ggufUnloadCalls: Int = await env.ggufSession.callCount(for: "unload")
        #expect(ggufUnloadCalls == 0, "GGUF session should not be affected")
    }

    @Test("Unload Multiple Times Is Safe")
    @MainActor
    internal func unloadMultipleTimesIsSafe() async throws {
        // Given - Model is loaded then unloaded
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)
        try await env.coordinator.unload()

        // Verify initial unload worked
        let initialUnloadCalls: Int = await env.mlxSession.callCount(for: "unload")
        #expect(initialUnloadCalls == 1, "Should have one unload call")

        // When - Unload is called again
        try await env.coordinator.unload()

        // Then - No additional unload should occur
        let finalUnloadCalls: Int = await env.mlxSession.callCount(for: "unload")
        #expect(finalUnloadCalls == 1, "Should still have only one unload call")

        // State should remain unloaded
        #expect(await !env.mlxSession.isModelLoaded, "Model should remain unloaded")
    }

    @Test("Stream After Unload Returns Error")
    @MainActor
    internal func streamAfterUnloadReturnsError() async throws {
        // Given - Model was loaded then unloaded
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)
        try await env.coordinator.unload()

        // When - Attempt to stream after unload
        let input: LLMInput = createLLMInput()
        var receivedError: Error?
        var receivedChunks: [String] = []

        do {
            for try await chunk in await env.coordinator.stream(input) {
                receivedChunks.append(chunk.text)
            }
        } catch {
            receivedError = error
        }

        // Then - Should receive modelNotFound error
        #expect(receivedError != nil, "Should receive an error")
        if let error = receivedError as? DatabaseError {
            #expect(error == .modelNotFound, "Error should be modelNotFound")
        }
        #expect(receivedChunks.isEmpty, "Should not receive any chunks")
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
            displayDescription: "A test model for unload operations",
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
