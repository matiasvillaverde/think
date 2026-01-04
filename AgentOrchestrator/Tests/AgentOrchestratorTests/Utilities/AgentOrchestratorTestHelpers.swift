import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
@testable import Database
import Foundation
import Testing
import Tools

internal enum AgentOrchestratorTestHelpers {
    internal static let kMegabyte: UInt64 = 1_048_576
    private static let kDefaultImageModelName: String = "test-default-image-model"
    private static let kGigabyte: UInt64 = 1_000_000_000
    private static let kKilobyte: UInt64 = 1_024
    private static let kModelVersion: Int = 1
    private static let kChunkDelay: TimeInterval = 0.001
    private static let kMultiplier: Int = 2
    private static let kDefaultImageParameters: UInt64 = 512_000_000
    private static let kDefaultImageRamMultiplier: UInt64 = 128
    private static let kDefaultImageSizeMultiplier: UInt64 = 64
    private static let kDefaultImageRamNeeded: UInt64 = kDefaultImageRamMultiplier * kMegabyte
    private static let kDefaultImageSize: UInt64 = kDefaultImageSizeMultiplier * kMegabyte

    @MainActor
    internal static func createTestDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database: Database = try Database.new(configuration: config)
        try await seedDatabase(database)
        return database
    }

    @MainActor
    internal static func seedDatabase(_ database: Database) async throws {
        _ = try await database.write(PersonalityCommands.WriteDefault())
        let imageModel: ModelDTO = createDefaultImageModelDTO()
        try await database.write(
            ModelCommands.AddModels(modelDTOs: [imageModel])
        )
    }

    @MainActor
    internal static func setupChatWithModel(_ database: Database) async throws -> UUID {
        let languageModel: ModelDTO = createLanguageModelDTO()
        try await database.write(
            ModelCommands.AddModels(modelDTOs: [languageModel])
        )

        let personalityId: UUID = try await database.read(
            PersonalityCommands.GetDefault()
        )

        let models: [SendableModel] = try await database.read(
            ModelCommands.FetchAll()
        )

        guard let model = models.first else {
            throw DatabaseError.modelNotFound
        }

        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        ) as UUID
    }

    internal static func createLanguageModelDTO() -> ModelDTO {
        ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-language-model",
            displayName: "Test Language Model",
            displayDescription: "Language model for testing",
            skills: ["text-generation"],
            parameters: kGigabyte,
            ramNeeded: UInt64(kMultiplier) * kMegabyte * kKilobyte,
            size: kMegabyte * kKilobyte,
            locationHuggingface: "test/language",
            version: kModelVersion,
            architecture: .llama
        )
    }

    internal static func createDefaultImageModelDTO() -> ModelDTO {
        ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: kDefaultImageModelName,
            displayName: "Test Default Image Model",
            displayDescription: "Baseline image model for tests",
            skills: ["image-generation"],
            parameters: kDefaultImageParameters,
            ramNeeded: kDefaultImageRamNeeded,
            size: kDefaultImageSize,
            locationHuggingface: "test/default-image",
            version: kModelVersion,
            architecture: .stableDiffusion
        )
    }

    internal static func createOrchestrator(
        database: Database,
        mlxSession: MockLLMSession
    ) -> AgentOrchestrator {
        let mockDownloader: MockModelDownloader = MockModelDownloader()
        mockDownloader.configureForStandardTests()

        let coordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: mockDownloader
        )
        let persistor: MessagePersistor = MessagePersistor(database: database)

        let toolManager: ToolManager = ToolManager()
        return AgentOrchestrator(
            modelCoordinator: coordinator,
            persistor: persistor,
            contextBuilder: ContextBuilder(tooling: toolManager)
        )
    }

    internal static func createToolTestOrchestrator(
        database: Database,
        toolCall: String,
        finalResponse: String
    ) async -> AgentOrchestrator {
        let mlxSession: MockLLMSession = MockLLMSession()

        await mlxSession.setSequentialStreamResponses([
            .text(["Let me check the weather for you. ", toolCall], delayBetweenChunks: kChunkDelay),
            .text(["Based on the weather data, ", finalResponse], delayBetweenChunks: kChunkDelay)
        ])

        return createOrchestrator(
            database: database,
            mlxSession: mlxSession
        )
    }

    // Tool response creation helpers (no longer using mock configuration)
    private static func createWeatherToolResult(
        _: String,
        _ temp: String,
        _ condition: String
    ) -> ToolResponse {
        ToolResponse(
            requestId: UUID(),
            toolName: "get_weather",
            result: "{\"temperature\": \(temp), \"condition\": \"\(condition)\"}"
        )
    }

    internal static func createSingleToolResponse() -> [ToolResponse] {
        [
            ToolResponse(
                requestId: UUID(),
                toolName: "get_weather",
                result: "{\"temperature\": 72, \"condition\": \"sunny\"}"
            )
        ]
    }

    internal static func createMultipleToolResponses() -> [ToolResponse] {
        [
            createWeatherToolResult("San Francisco", "72", "sunny"),
            createWeatherToolResult("New York", "45", "cloudy")
        ]
    }

    internal static func createFailedToolResponse() -> ToolResponse {
        ToolResponse(
            requestId: UUID(),
            toolName: "failing_tool",
            result: "Error: Tool execution failed"
        )
    }
}
