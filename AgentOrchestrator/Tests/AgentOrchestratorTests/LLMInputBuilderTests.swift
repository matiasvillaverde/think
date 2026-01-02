import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
@testable import Database
import Foundation
import Testing
import Tools

@Suite("LLMInputBuilder Tests")
internal struct LLMInputBuilderTests {
    @MainActor
    private func createTestDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database: Database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        return database
    }

    private func createTestModel(
        architecture: Architecture = .llama
    ) -> SendableModel {
        SendableModel(
            id: UUID(),
            ramNeeded: 8_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture,
            backend: .mlx,
            locationKind: .huggingFace
        )
    }

    @Test("Should build LLMInput with configuration from database")
    @MainActor
    internal func testBuildLLMInputWithConfiguration() async throws {
        let setup: BuilderSetup = try await createSetup("Test context with user prompt")
        let input: LLMInput = try await buildInput(setup: setup)
        verifyBasicConfiguration(input)
    }

    private func buildInput(setup: BuilderSetup) async throws -> LLMInput {
        let builder: LLMInputBuilder = LLMInputBuilder(
            chat: setup.chatId,
            model: setup.model,
            database: setup.database,
            contextBuilder: ContextBuilder(tooling: ToolManager())
        )
        return try await builder.build(context: setup.context)
    }

    private func verifyBasicConfiguration(_ input: LLMInput) {
        #expect(input.context == "Test context with user prompt")
        // Default personality values
        #expect(input.sampling.temperature == 0.7)
        #expect(input.sampling.topP == 1.0)
        #expect(input.limits.maxTokens == 10_240)
        #expect(input.limits.collectDetailedMetrics == true)
    }

    @MainActor
    private func createSetup(
        _ context: String,
        architecture: Architecture = .llama
    ) async throws -> BuilderSetup {
        let database: Database = try await createTestDatabase()
        let chatId: UUID = try await setupChatWithConfig(
            database: database,
            architecture: architecture
        )
        return BuilderSetup(
            database: database,
            chatId: chatId,
            context: context,
            model: createTestModel(architecture: architecture)
        )
    }

    private struct BuilderSetup {
        let database: any DatabaseProtocol
        let chatId: UUID
        let context: String
        let model: SendableModel
    }

    @Test("Should include stop sequences from context builder")
    @MainActor
    internal func testIncludesStopSequences() async throws {
        let setup: BuilderSetup = try await createSetup(
            "Test context",
            architecture: .mistral
        )
        let input: LLMInput = try await buildInput(setup: setup)
        #expect(input.sampling.stopSequences.count >= 2,
            "Mistral should have at least 2 stop sequences, got \(input.sampling.stopSequences.count)")
        #expect(input.sampling.stopSequences.contains("</s>"),
            "Mistral should include </s> stop sequence")
        #expect(input.sampling.stopSequences.contains("<|im_end|>"),
            "Mistral should include <|im_end|> stop sequence")
    }

    @Test("Should handle nil repetition penalty")
    @MainActor
    internal func testHandlesNilRepetitionPenalty() async throws {
        let setup: BuilderSetup = try await createSetup(
            "Test context",
            architecture: .phi
        )
        let input: LLMInput = try await buildInput(setup: setup)
        // Default personality has no repetition penalty
        #expect(input.sampling.repetitionPenalty == nil)
        #expect(input.sampling.frequencyPenalty == nil)
        #expect(input.sampling.presencePenalty == nil)
        #expect(input.sampling.seed == nil)
    }

    @Test("Should use different stop sequences for different models")
    @MainActor
    internal func testDifferentStopSequencesPerModel() async throws {
        let setup: BuilderSetup = try await createSetup("Test context")
        try await verifyArchitectureStopSequences(setup)
    }

    private func verifyArchitectureStopSequences(_ setup: BuilderSetup) async throws {
        let buildInput: (Architecture) async throws -> LLMInput = { arch in
            let model: SendableModel = createTestModel(architecture: arch)
            let builder: LLMInputBuilder = LLMInputBuilder(
                chat: setup.chatId,
                model: model,
                database: setup.database,
                contextBuilder: ContextBuilder(tooling: ToolManager())
            )
            return try await builder.build(context: setup.context)
        }
        let llamaInput: LLMInput = try await buildInput(.llama)
        #expect(llamaInput.sampling.stopSequences.contains("<|eot_id|>"))
        let phiInput: LLMInput = try await buildInput(.phi)
        #expect(phiInput.sampling.stopSequences.contains("<|im_end|>"))
        let qwenInput: LLMInput = try await buildInput(.qwen)
        #expect(qwenInput.sampling.stopSequences.contains("<|im_end|>"))
    }

    @Test("Should preserve all configuration values")
    @MainActor
    internal func testPreservesAllConfigurationValues() async throws {
        let setup: BuilderSetup = try await createSetup("Detailed test context")
        let input: LLMInput = try await buildInput(setup: setup)
        verifyDetailedConfiguration(input)
    }

    private func verifyDetailedConfiguration(_ input: LLMInput) {
        verifyContext(input)
        verifySamplingParameters(input)
        verifyResourceLimits(input)
        verifyMedia(input)
    }

    private func verifyContext(_ input: LLMInput) {
        #expect(input.context == "Detailed test context",
            "Context should be preserved exactly as provided")
    }

    private func verifySamplingParameters(_ input: LLMInput) {
        #expect(input.sampling.temperature == 0.7,
            "Temperature should be 0.7 (default value)")
        #expect(input.sampling.topP == 1.0,
            "Top-p should be 1.0 (no nucleus sampling)")
        #expect(input.sampling.topK == nil,
            "Top-k should be nil (not using top-k sampling)")
        #expect(input.sampling.repetitionPenalty == nil,
            "Repetition penalty should be nil for default personality")
        #expect(input.sampling.repetitionPenaltyRange == 20,
            "Repetition penalty range should be 20 (default)")
        #expect(input.sampling.frequencyPenalty == nil,
            "Frequency penalty should be nil (not configured)")
        #expect(input.sampling.presencePenalty == nil,
            "Presence penalty should be nil (not configured)")
        #expect(input.sampling.seed == nil,
            "Seed should be nil (non-deterministic generation)")
    }

    private func verifyResourceLimits(_ input: LLMInput) {
        #expect(input.limits.maxTokens == 10_240,
            "Max tokens should be 10240 (default limit)")
        #expect(input.limits.maxTime == nil,
            "Max time should be nil (no time limit)")
        #expect(input.limits.collectDetailedMetrics == true,
            "Should collect detailed metrics by default")
    }

    private func verifyMedia(_ input: LLMInput) {
        #expect(input.images.isEmpty,
            "Should have no images for text-only input")
        #expect(input.videoURLs.isEmpty,
            "Should have no videos for text-only input")
    }

    @MainActor
    private func setupChatWithConfig(
        database: Database,
        architecture: Architecture
    ) async throws -> UUID {
        let modelDTO: ModelDTO = createModelDTO(architecture: architecture)
        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.architecture == architecture }) else {
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

    private func createModelDTO(architecture: Architecture) -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-\(architecture)",
            displayName: "Test \(architecture) Model",
            displayDescription: "Test model for \(architecture) architecture",
            skills: ["text-generation"],
            parameters: 1_000_000,
            ramNeeded: 100 * megabyte,
            size: 50 * megabyte,
            locationHuggingface: "test/\(architecture)-model",
            version: 2,
            architecture: architecture
        )
    }
}
