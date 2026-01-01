import Abstractions
import AbstractionsTestUtilities
import Foundation
import Testing
@testable import Database
@testable import Tools

@Suite("Canvas Strategy Tests")
struct CanvasStrategyTests {
    @Test("Create and append canvas via tool")
    @MainActor
    func createAndAppendCanvas() async throws {
        let database = try await Self.makeDatabase()
        let chatId = try await Self.createChat(database: database)
        let strategy = CanvasStrategy(database: database)

        let createRequest = ToolRequest(
            name: "canvas",
            arguments: "{\"action\":\"create\",\"title\":\"Canvas\",\"content\":\"Hello\"}",
            context: ToolRequestContext(chatId: chatId, messageId: nil)
        )
        let createResponse = await strategy.execute(request: createRequest)
        #expect(createResponse.error == nil)

        let appendRequest = ToolRequest(
            name: "canvas",
            arguments: "{\"action\":\"append\",\"content\":\"World\"}",
            context: ToolRequestContext(chatId: chatId, messageId: nil)
        )
        let appendResponse = await strategy.execute(request: appendRequest)
        #expect(appendResponse.error == nil)

        let canvases = try await database.read(CanvasCommands.List(chatId: chatId))
        #expect(canvases.count == 1)
        #expect(canvases.first?.content == "Hello\nWorld")
    }

    private static func makeDatabase() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        try await addRequiredModels(database)
        return database
    }

    private static func addRequiredModels(_ database: Database) async throws {
        try await database.write(PersonalityCommands.WriteDefault())

        let languageModel = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-llm",
            displayName: "Test LLM",
            displayDescription: "Test language model",
            skills: ["text-generation"],
            parameters: 1_000,
            ramNeeded: 64,
            size: 128,
            locationHuggingface: "test/llm",
            version: 1
        )

        let imageModel = ModelDTO(
            type: .diffusion,
            backend: .mlx,
            name: "test-image",
            displayName: "Test Image",
            displayDescription: "Test image model",
            skills: ["image-generation"],
            parameters: 1_000,
            ramNeeded: 64,
            size: 128,
            locationHuggingface: "test/image",
            version: 1
        )

        try await database.write(ModelCommands.AddModels(models: [languageModel, imageModel]))
    }

    private static func createChat(database: Database) async throws -> UUID {
        let personalityId = try await database.read(PersonalityCommands.GetDefault())
        let models = try await database.read(ModelCommands.FetchAll())
        guard let languageModel = models.first(where: { $0.modelType.isLanguageCapable }) else {
            throw DatabaseError.modelNotFound
        }
        return try await database.write(
            ChatCommands.CreateWithModel(modelId: languageModel.id, personalityId: personalityId)
        )
    }
}
