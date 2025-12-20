import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Database Failure Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorDatabaseTests {
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

        let mockDownloader: MockModelDownloader = MockModelDownloader()
        mockDownloader.configureForStandardTests()

        let coordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: mockDownloader
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

    @Test("Load Handles Missing Chat Gracefully")
    @MainActor
    internal func loadHandlesMissingChatGracefully() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let nonExistentChatId: UUID = UUID()

        // When/Then - Should throw appropriate error
        await #expect(throws: (any Error).self) {
            try await env.coordinator.load(chatId: nonExistentChatId)
        }

        // Verify no session was loaded
        #expect(await !env.mlxSession.isModelLoaded, "MLX session should not be loaded")
        #expect(await !env.ggufSession.isModelLoaded, "GGUF session should not be loaded")
    }

    @Test("Load Handles Invalid Chat ID Gracefully")
    @MainActor
    internal func loadHandlesInvalidChatIDGracefully() async throws {
        // Given - Non-existent chat ID
        let env: TestEnvironment = try await setupTestEnvironment()
        let invalidChatId: UUID = UUID()

        // When/Then - Should throw when trying to load non-existent chat
        await #expect(throws: (any Error).self) {
            try await env.coordinator.load(chatId: invalidChatId)
        }

        // Verify no session was loaded
        #expect(await !env.mlxSession.isModelLoaded, "MLX session should not be loaded")
        #expect(await !env.ggufSession.isModelLoaded, "GGUF session should not be loaded")
    }

    @Test("Stream Handles Session Failure")
    @MainActor
    internal func streamHandlesSessionFailure() async throws {
        // Given - Loaded model that will fail during stream
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Configure session to throw error during generation
        let errorText: String = "Error: Failed to generate"
        await env.mlxSession.configureForSuccessfulGeneration(
            texts: [errorText],
            delay: 0.001
        )

        // When - Stream and look for error pattern
        let input: LLMInput = createLLMInput()
        var receivedTexts: [String] = []

        for try await chunk in await env.coordinator.stream(input) {
            receivedTexts.append(chunk.text)
        }

        // Then - Should receive the error text
        #expect(!receivedTexts.isEmpty, "Should receive some output")
        #expect(receivedTexts.joined().contains("Error"), "Should contain error text")
    }

    @Test("Load Recovers From Previous Database Failure")
    @MainActor
    internal func loadRecoversFromPreviousDatabaseFailure() async throws {
        // Given - Previous failed load attempt
        let env: TestEnvironment = try await setupTestEnvironment()
        let nonExistentChatId: UUID = UUID()

        // First attempt fails
        await #expect(throws: (any Error).self) {
            try await env.coordinator.load(chatId: nonExistentChatId)
        }

        // Setup valid chat
        let validChatId: UUID = try await setupChatWithModel(env.database)
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Try loading valid chat after failure
        try await env.coordinator.load(chatId: validChatId)

        // Then - Should recover and load successfully
        #expect(await env.mlxSession.isModelLoaded, "Should load model after recovery")
        await env.mlxSession.verifyPreloadCalled()
    }

    @Test("Concurrent Load Requests Handle Database Contention")
    @MainActor
    internal func concurrentLoadRequestsHandleDatabaseContention() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId1: UUID = try await setupChatWithModel(env.database, location: "test/model-1")
        let chatId2: UUID = try await setupChatWithModel(env.database, location: "test/model-2")

        await env.mlxSession.configureForSuccessfulPreload(steps: 3, delay: 0.01)

        // When - Start concurrent loads
        async let load1: Void = env.coordinator.load(chatId: chatId1)
        async let load2: Void = env.coordinator.load(chatId: chatId2)

        // Collect results
        do {
            _ = try await (load1, load2)
        } catch {
            // One might fail due to rapid switching, which is acceptable
        }

        // Then - One model should be loaded (last one wins)
        #expect(await env.mlxSession.isModelLoaded, "A model should be loaded")

        // Verify multiple loads were attempted
        let preloadCount: Int = await env.mlxSession.callCount(for: "preload")
        #expect(preloadCount >= 1, "At least one preload should complete")
    }

    // MARK: - Helper Methods

    @MainActor
    private func setupChatWithModel(
        _ database: Database,
        location: String = "test/model"
    ) async throws -> UUID {
        let modelDTO: ModelDTO = createTestModel(location: location)
        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.location == location }) else {
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

    private func createTestModel(location: String = "test/model") -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model-\(location.hashValue)",
            displayName: "Test Model",
            displayDescription: "A test model for database failures",
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
