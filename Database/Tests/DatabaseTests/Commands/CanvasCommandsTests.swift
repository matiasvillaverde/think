import Abstractions
import AbstractionsTestUtilities
import Foundation
import Testing
@testable import Database

@Suite("Canvas Commands Tests")
struct CanvasCommandsTests {
    @Test("Create and update canvas")
    @MainActor
    func createAndUpdateCanvas() async throws {
        let database = try await Self.makeDatabase()
        let chatId = try await Self.createChat(database: database)

        let canvasId = try await database.write(
            CanvasCommands.Create(
                title: "Canvas",
                content: "Draft",
                chatId: chatId
            )
        )

        var canvas = try await database.read(CanvasCommands.Get(id: canvasId))
        #expect(canvas.title == "Canvas")
        #expect(canvas.content == "Draft")

        _ = try await database.write(
            CanvasCommands.Update(id: canvasId, content: "Updated")
        )

        canvas = try await database.read(CanvasCommands.Get(id: canvasId))
        #expect(canvas.content == "Updated")
    }

    @Test("Delete canvas removes it from list")
    @MainActor
    func deleteCanvasRemovesIt() async throws {
        let database = try await Self.makeDatabase()
        let chatId = try await Self.createChat(database: database)

        let canvasId = try await database.write(
            CanvasCommands.Create(
                title: "Canvas",
                content: "Draft",
                chatId: chatId
            )
        )

        _ = try await database.write(CanvasCommands.Delete(id: canvasId))

        let canvases = try await database.read(CanvasCommands.List(chatId: chatId))
        #expect(canvases.contains { $0.id == canvasId } == false)
    }

    private static func makeDatabase() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        try await addRequiredModelsForChatCommands(database)
        return database
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
