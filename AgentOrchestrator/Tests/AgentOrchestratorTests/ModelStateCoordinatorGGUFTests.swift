import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator GGUF Backend Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorGGUFTests {
    // MARK: - Test Environment

    internal struct TestEnvironment {
        internal let database: Database
        internal let mlxSession: MockLLMSession
        internal let ggufSession: MockLLMSession
        internal let imageGenerator: MockImageGenerating
        internal let coordinator: ModelStateCoordinator
        internal let chatId: UUID
    }

    // MARK: - Test Helpers

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try await createAndInitializeDatabase()
        let chatId: UUID = try await createChatWithGGUFModel(database)

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

        // Add GGUF model that ModelStateCoordinator can use
        try await addGGUFModel(database)

        return database
    }

    @MainActor
    private func addGGUFModel(_ database: Database) async throws {
        let ggufModel: ModelDTO = createTestGGUFModel()
        try await database.write(ModelCommands.AddModels(modelDTOs: [ggufModel]))
    }

    private func createTestGGUFModel() -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .gguf,
            name: "test-gguf-llm",
            displayName: "Test GGUF LLM",
            displayDescription: "A test GGUF language model",
            skills: ["text-generation"],
            parameters: 1_500_000,
            ramNeeded: 150 * megabyte,
            size: 75 * megabyte,
            locationHuggingface: "test/gguf-llm",
            version: 2,
            architecture: .llama
        )
    }

    @MainActor
    private func createChatWithGGUFModel(_ database: Database) async throws -> UUID {
        // Get the default personality (created during app initialization)
        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())

        // Get the GGUF model
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())

        var ggufModel: SendableModel?
        for model in models where model.location == "test/gguf-llm" {
            ggufModel = model
            break
        }

        guard let model = ggufModel else {
            throw DatabaseError.modelNotFound
        }

        // Create chat with GGUF model
        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )
    }

    private func createLLMInput() -> LLMInput {
        LLMInput(
            context: "Test GGUF prompt",
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

    // MARK: - Tests

    @Test("Load GGUF Model Uses GGUF Session")
    @MainActor
    internal func loadGGUFModelUsesGGUFSession() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        await env.ggufSession.configureForSuccessfulPreload(steps: 3, delay: 0.001)
        let expectedChunks: [String] = ["GGUF", " response", " text"]
        await env.ggufSession.configureForSuccessfulGeneration(texts: expectedChunks, delay: 0.001)

        // Verify model is GGUF
        let model: SendableModel = try await env.database.read(
            ChatCommands.GetLanguageModel(chatId: env.chatId)
        )
        #expect(model.location == "test/gguf-llm", "Should have GGUF model")
        #expect(model.backend == .gguf, "Model backend should be GGUF")

        // When - Load and verify GGUF session usage
        try await env.coordinator.load(chatId: env.chatId)
        await verifyGGUFSessionUsed(env)

        // When - Generate and verify text
        let receivedChunks: [String] = try await generateText(env)
        #expect(receivedChunks == expectedChunks, "Should receive GGUF chunks")
    }

    private func verifyGGUFSessionUsed(_ env: TestEnvironment) async {
        await env.ggufSession.verifyPreloadCalled()
        #expect(await env.ggufSession.isModelLoaded, "GGUF session should report model as loaded")
        let mlxCallCount: Int = await env.mlxSession.callCount(for: "preload")
        #expect(mlxCallCount == 0, "MLX session should not be called for GGUF model")
    }

    private func generateText(_ env: TestEnvironment) async throws -> [String] {
        let input: LLMInput = createLLMInput()
        var receivedChunks: [String] = []
        for try await chunk in await env.coordinator.stream(input) {
            receivedChunks.append(chunk.text)
        }
        await env.ggufSession.verifyStreamCalled(with: "Test GGUF prompt")
        let mlxStreamCount: Int = await env.mlxSession.callCount(for: "stream")
        #expect(mlxStreamCount == 0, "MLX session should not be used for streaming")
        return receivedChunks
    }
}
