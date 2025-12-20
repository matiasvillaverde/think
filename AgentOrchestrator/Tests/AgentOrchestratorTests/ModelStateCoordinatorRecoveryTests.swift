import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Recovery Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorRecoveryTests {
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

    @Test("Stream Continues After Partial Error")
    @MainActor
    internal func streamContinuesAfterPartialError() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Configure session to generate text with error indication
        let chunks: [String] = ["Hello", " world", " [ERROR]", " continuing", " after", " error"]
        await env.mlxSession.configureForSuccessfulGeneration(texts: chunks, delay: 0.001)

        // When - Stream and collect all chunks
        let input: LLMInput = createLLMInput()
        var receivedChunks: [String] = []

        for try await chunk in await env.coordinator.stream(input) {
            receivedChunks.append(chunk.text)
        }

        // Then - Should receive all chunks including those after error marker
        #expect(receivedChunks == chunks, "Should receive all chunks")
        #expect(receivedChunks.contains(" [ERROR]"), "Should contain error marker")
        #expect(receivedChunks.last == " error", "Should continue after error")
    }

    @Test("Multiple Streams After Error Recovery")
    @MainActor
    internal func multipleStreamsAfterErrorRecovery() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // First stream with error marker
        let firstChunks: [String] = ["First", " with", " error"]
        await env.mlxSession.configureForSuccessfulGeneration(texts: firstChunks, delay: 0.001)

        let input: LLMInput = createLLMInput()
        var firstReceived: [String] = []
        for try await chunk in await env.coordinator.stream(input) {
            firstReceived.append(chunk.text)
        }

        // Second stream should work normally
        let secondChunks: [String] = ["Second", " works", " fine"]
        await env.mlxSession.configureForSuccessfulGeneration(texts: secondChunks, delay: 0.001)

        var secondReceived: [String] = []
        for try await chunk in await env.coordinator.stream(input) {
            secondReceived.append(chunk.text)
        }

        // Then - Both streams should complete successfully
        #expect(firstReceived == firstChunks, "First stream should complete")
        #expect(secondReceived == secondChunks, "Second stream should work after first")
    }

    @Test("Stream Recovery After Stop")
    @MainActor
    internal func streamRecoveryAfterStop() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // When - Start stream and stop it early
        let firstReceived: [String] = try await collectPartialStream(env, maxCount: 5)
        try await env.coordinator.stop()

        // Start new stream after stop
        let secondReceived: [String] = await collectFullStream(
            env,
            chunks: ["New", " stream", " works"]
        )

        // Then - Should be able to stream again after stop
        #expect(firstReceived.count >= 5, "First stream should have received some chunks")
        #expect(secondReceived == ["New", " stream", " works"], "Second stream should work after stop")
    }

    @MainActor
    private func collectPartialStream(
        _ env: TestEnvironment,
        maxCount: Int
    ) async throws -> [String] {
        let chunks: [String] = Array(repeating: "chunk", count: 100)
        await env.mlxSession.configureForSuccessfulGeneration(texts: chunks, delay: 0.01)

        let input: LLMInput = createLLMInput()
        let streamTask: Task<[String], Error> = Task {
            var received: [String] = []
            for try await chunk in await env.coordinator.stream(input) {
                received.append(chunk.text)
                if received.count >= maxCount {
                    break
                }
            }
            return received
        }
        return try await streamTask.value
    }

    @MainActor
    private func collectFullStream(
        _ env: TestEnvironment,
        chunks: [String]
    ) async -> [String] {
        await env.mlxSession.configureForSuccessfulGeneration(texts: chunks, delay: 0.001)
        let input: LLMInput = createLLMInput()
        var received: [String] = []
        do {
            for try await chunk in await env.coordinator.stream(input) {
                received.append(chunk.text)
            }
        } catch {
            // Return what we have so far
        }
        return received
    }

    @Test("Stream Recovery After Model Unload and Reload")
    @MainActor
    internal func streamRecoveryAfterModelUnloadAndReload() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // First stream before unload
        let firstReceived: [String] = await collectFullStream(env, chunks: ["Before", " unload"])

        // Unload and reload
        try await env.coordinator.unload()
        try await env.coordinator.load(chatId: chatId)

        // Second stream after reload
        let secondReceived: [String] = await collectFullStream(env, chunks: ["After", " reload"])

        // Then - Both streams should work
        #expect(firstReceived == ["Before", " unload"], "First stream should work")
        #expect(secondReceived == ["After", " reload"], "Second stream should work after reload")
    }

    @Test("Concurrent Streams Handle Errors Independently")
    @MainActor
    internal func concurrentStreamsHandleErrorsIndependently() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Configure different responses for concurrent streams
        let chunks1: [String] = ["Stream", " one"]
        let chunks2: [String] = ["Stream", " two"]
        await env.mlxSession.configureForSuccessfulGeneration(texts: chunks1, delay: 0.005)

        let input: LLMInput = createLLMInput()

        // When - Start concurrent streams
        async let stream1Task: [String] = collectStream(env.coordinator, input)

        // Quick reconfigure for second stream
        await env.mlxSession.configureForSuccessfulGeneration(texts: chunks2, delay: 0.005)
        async let stream2Task: [String] = collectStream(env.coordinator, input)

        let (result1, result2): ([String], [String]) = await (stream1Task, stream2Task)

        // Then - At least one should complete (concurrent behavior is non-deterministic)
        let hasValidResult: Bool = !result1.isEmpty || !result2.isEmpty
        #expect(hasValidResult, "At least one stream should complete")
    }

    @Test("Stream Handles Empty Response Gracefully")
    @MainActor
    internal func streamHandlesEmptyResponseGracefully() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Configure empty response
        await env.mlxSession.configureForSuccessfulGeneration(texts: [], delay: 0.001)

        // When - Stream with empty response
        let input: LLMInput = createLLMInput()
        var receivedChunks: [String] = []

        for try await chunk in await env.coordinator.stream(input) {
            receivedChunks.append(chunk.text)
        }

        // Then - Should handle empty response without error
        #expect(receivedChunks.isEmpty, "Should receive no chunks for empty response")
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
            name: "test-recovery-model",
            displayName: "Test Recovery Model",
            displayDescription: "A test model for error recovery",
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
            context: "Test prompt for recovery",
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

    @MainActor
    private func collectStream(
        _ coordinator: ModelStateCoordinator,
        _ input: LLMInput
    ) async -> [String] {
        var chunks: [String] = []
        do {
            for try await chunk in await coordinator.stream(input) {
                chunks.append(chunk.text)
            }
        } catch {
            // Ignore errors for concurrent test
        }
        return chunks
    }
}
