import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

/// Tests for model fallback scenarios.
@Suite("ModelStateCoordinator Fallback Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorFallbackTests {
    internal struct TestEnvironment {
        internal let database: Database
        internal let mlxSession: MockLLMSession
        internal let ggufSession: MockLLMSession
        internal let imageGenerator: MockImageGenerating
        internal let coordinator: ModelStateCoordinator
    }

    private enum TestError: Error { case modelNotFound, simulatedFailure }

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try await createAndInitializeDatabase()
        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()
        let imageGenerator: MockImageGenerating = MockImageGenerating()
        return TestEnvironment(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            coordinator: ModelStateCoordinator(
                database: database,
                mlxSession: mlxSession,
                ggufSession: ggufSession,
                imageGenerator: imageGenerator,
                modelDownloader: MockModelDownloader.createConfiguredMock()
            )
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

    @Test("Load failure throws error")
    @MainActor
    internal func loadFailureThrowsError() async throws {
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await createChatWithModel(env.database)
        await env.mlxSession.configureForPreloadError(TestError.simulatedFailure)
        await #expect(throws: Error.self) { try await env.coordinator.load(chatId: chatId) }
    }

    @Test("Successful load after previous failure")
    @MainActor
    internal func successfulLoadAfterPreviousFailure() async throws {
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await createChatWithModel(env.database)
        await env.mlxSession.configureForPreloadError(TestError.simulatedFailure)
        do { try await env.coordinator.load(chatId: chatId) } catch { /* Expected */ }
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)
        let chunks: [String] = try await collectStream(env, env.mlxSession, ["Hello"])
        #expect(!chunks.isEmpty)
    }

    @Test("Multiple models can be added to database")
    @MainActor
    internal func multipleModelsCanBeAddedToDatabase() async throws {
        let env: TestEnvironment = try await setupTestEnvironment()
        let primary: ModelDTO = createModel(
            name: "primary",
            location: "test/primary",
            params: 7_000_000_000
        )
        let fallback: ModelDTO = createModel(
            name: "fallback",
            location: "test/fallback",
            params: 3_000_000_000
        )
        try await env.database.write(ModelCommands.AddModels(modelDTOs: [primary, fallback]))
        let models: [SendableModel] = try await env.database.read(ModelCommands.FetchAll())
        let languageModels: [SendableModel] = models.filter { $0.modelType == .language }
        #expect(languageModels.count >= 2)
    }

    @Test("Model state resets after unload allowing fresh load attempt")
    @MainActor
    internal func modelStateResetsAfterUnload() async throws {
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await createChatWithModel(env.database)
        await env.mlxSession.configureForPreloadError(TestError.simulatedFailure)
        do { try await env.coordinator.load(chatId: chatId) } catch { /* Expected */ }
        _ = try await env.database.write(ModelCommands.ResetAllRuntimeStates())
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)
        let chunks: [String] = try await collectStream(env, env.mlxSession, ["After reset"])
        #expect(chunks == ["After reset"])
    }

    @Test("Different backend can be loaded successfully")
    @MainActor
    internal func differentBackendCanBeLoadedSuccessfully() async throws {
        let env: TestEnvironment = try await setupTestEnvironment()
        let mlx: ModelDTO = createModel(
            name: "mlx-primary",
            location: "test/mlx-primary",
            backend: .mlx
        )
        let gguf: ModelDTO = createModel(
            name: "gguf-fallback",
            location: "test/gguf-fallback",
            backend: .gguf
        )
        try await env.database.write(ModelCommands.AddModels(modelDTOs: [mlx, gguf]))
        await env.mlxSession.configureForPreloadError(TestError.simulatedFailure)
        await env.ggufSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        let chatId: UUID = try await createChatWithLocation(env.database, "test/gguf-fallback")
        try await env.coordinator.load(chatId: chatId)
        let chunks: [String] = try await collectStream(env, env.ggufSession, ["GGUF works"])
        #expect(chunks == ["GGUF works"])
    }

    @Test("Smaller model can be loaded when available")
    @MainActor
    internal func smallerModelCanBeLoadedWhenAvailable() async throws {
        let env: TestEnvironment = try await setupTestEnvironment()
        let large: ModelDTO = createModel(
            name: "large",
            location: "test/large",
            params: 13_000_000_000
        )
        let small: ModelDTO = createModel(
            name: "small",
            location: "test/small",
            params: 3_000_000_000
        )
        try await env.database.write(ModelCommands.AddModels(modelDTOs: [large, small]))
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        let chatId: UUID = try await createChatWithLocation(env.database, "test/small")
        try await env.coordinator.load(chatId: chatId)
        let chunks: [String] = try await collectStream(env, env.mlxSession, ["Small model"])
        #expect(chunks == ["Small model"])
    }

    // MARK: - Helpers

    @MainActor
    private func collectStream(
        _ env: TestEnvironment,
        _ session: MockLLMSession,
        _ texts: [String]
    ) async throws -> [String] {
        await session.configureForSuccessfulGeneration(texts: texts, delay: 0.001)
        let input: LLMInput = createLLMInput()
        var chunks: [String] = []
        for try await chunk in await env.coordinator.stream(input) { chunks.append(chunk.text) }
        return chunks
    }

    @MainActor
    private func createChatWithModel(_ database: Database) async throws -> UUID {
        let modelDTO: ModelDTO = createModel(name: "test-model", location: "test/model")
        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        return try await createChatWithLocation(database, "test/model")
    }

    @MainActor
    private func createChatWithLocation(
        _ database: Database,
        _ location: String
    ) async throws -> UUID {
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.location == location }) else {
            throw TestError.modelNotFound
        }
        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        return try await database.write(
            ChatCommands.CreateWithModel(modelId: model.id, personalityId: personalityId)
        )
    }

    private func createModel(
        name: String,
        location: String,
        backend: SendableModel.Backend = .mlx,
        params: UInt64 = 1_000_000
    ) -> ModelDTO {
        ModelDTO(
            type: .language,
            backend: backend,
            name: name,
            displayName: "Test \(name)",
            displayDescription: "Model for fallback tests",
            skills: ["text-generation"],
            parameters: params,
            ramNeeded: params / 10,
            size: params / 20,
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
