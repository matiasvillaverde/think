import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Stream Error Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorStreamErrorTests {
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

    // MARK: - Tests

    @Test("Stream Without Loaded Model Returns Error")
    @MainActor
    internal func streamWithoutLoadedModelReturnsError() async throws {
        // Given - Coordinator with no loaded model
        let env: TestEnvironment = try await setupTestEnvironment()

        // When - Attempt to stream without loading a model
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
        } else {
            Issue.record("Expected DatabaseError.modelNotFound but got \(String(describing: receivedError))")
        }
        #expect(receivedChunks.isEmpty, "Should not receive any chunks")
    }

    @Test("Stream Error During Generation Is Propagated")
    @MainActor
    internal func streamErrorDuringGenerationPropagated() async throws {
        // Given - Model is loaded and configured to fail during generation
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        // Configure and load model
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Configure session to fail during generation
        let generationError: LLMError = .providerError(code: "TEST_ERROR", message: "Test generation failure")
        await env.mlxSession.configureForGenerationError(generationError)

        // When - Stream generation with error
        let result: StreamResult = await streamWithErrorHandling(env.coordinator)

        // Then - Error should be propagated
        verifyStreamError(result, expectedError: generationError)
        #expect(result.chunks.isEmpty, "Should not receive any chunks before error")
    }

    @Test("Stream Error After Successful Start")
    @MainActor
    internal func streamErrorAfterSuccessfulStart() async throws {
        // Given - Model loaded
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        try await env.coordinator.load(chatId: chatId)

        // Configure to fail immediately (simulating error during generation)
        let generationError: LLMError = .providerError(
            code: "STREAM_FAILURE",
            message: "Failed during generation"
        )
        await env.mlxSession.configureForGenerationError(generationError)

        // When - Stream generation
        let result: StreamResult = await streamWithErrorHandling(env.coordinator)

        // Then - Should receive error without chunks
        #expect(result.chunks.isEmpty, "Should not receive chunks when error occurs immediately")
        verifyPartialStreamError(result, code: "STREAM_FAILURE", message: "Failed during generation")
    }

    // MARK: - Helper Methods

    private struct StreamResult {
        let chunks: [String]
        let error: Error?
    }

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

    private func streamWithErrorHandling(_ coordinator: ModelStateCoordinator) async -> StreamResult {
        let input: LLMInput = createLLMInput()
        var receivedError: Error?
        var receivedChunks: [String] = []

        do {
            for try await chunk in await coordinator.stream(input) {
                receivedChunks.append(chunk.text)
            }
        } catch {
            receivedError = error
        }

        return StreamResult(chunks: receivedChunks, error: receivedError)
    }

    private func verifyStreamError(_ result: StreamResult, expectedError: LLMError) {
        guard let error = result.error else {
            Issue.record("Expected error but none was received")
            return
        }

        guard let llmError = error as? LLMError else {
            Issue.record("Expected LLMError but got \(type(of: error)): \(error)")
            return
        }

        verifyLLMErrorMatch(expected: expectedError, actual: llmError)

        // Verify no chunks were received before error
        #expect(result.chunks.isEmpty,
            "Should not receive chunks when error occurs immediately, got \(result.chunks.count) chunks")
    }

    private func verifyLLMErrorMatch(expected: LLMError, actual: LLMError) {
        switch (expected, actual) {
        case let (.providerError(expectedCode, expectedMessage),
            .providerError(actualCode, actualMessage)):
            #expect(actualCode == expectedCode,
                "Error code mismatch - expected: '\(expectedCode)', actual: '\(actualCode)'")
            #expect(actualMessage == expectedMessage,
                "Error message mismatch - expected: '\(expectedMessage)', actual: '\(actualMessage)'")

        case (.modelNotFound, .modelNotFound):
            // Match - no additional properties to verify
            break

        default:
            Issue.record("Error type mismatch - expected: \(expected), actual: \(actual)")
        }
    }

    private func verifyPartialStreamError(_ result: StreamResult, code: String, message: String) {
        guard let error = result.error else {
            Issue.record("Expected error with code '\(code)' but none was received")
            return
        }

        guard let llmError = error as? LLMError else {
            Issue.record("Expected LLMError but got \(type(of: error)): \(error)")
            return
        }

        switch llmError {
        case let .providerError(errorCode, errorMessage):
            #expect(errorCode == code,
                "Error code mismatch - expected: '\(code)', actual: '\(errorCode)'")
            #expect(errorMessage == message,
                "Error message mismatch - expected: '\(message)', actual: '\(errorMessage)'")

        default:
            Issue.record("Expected provider error with code '\(code)' but got: \(llmError)")
        }
    }

    private func createTestModel() -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model",
            displayName: "Test Model",
            displayDescription: "A test model for error handling",
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
