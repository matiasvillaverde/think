import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Testing

@Suite("Remote Model Commands Tests")
struct RemoteModelCommandsTests {
    private func createTestDatabase() throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        return try Database.new(configuration: config)
    }

    @Test("CreateRemoteModel stores a remote model and marks it downloaded")
    @MainActor
    func createRemoteModelStoresData() async throws {
        let database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let location = "openrouter:openai/gpt-4o-mini"
        let modelId = try await database.write(
            ModelCommands.CreateRemoteModel(
                name: "openai/gpt-4o-mini",
                displayName: "GPT-4o Mini",
                displayDescription: "Remote model",
                location: location,
                type: .language
            )
        )

        let model = try await database.read(
            ModelCommands.GetModelByLocation(location: location)
        )

        #expect(model?.id == modelId)
        #expect(model?.backend == .remote)
        #expect(model?.locationKind == .remote)
        #expect(model?.state == .downloaded)
        #expect(model?.downloadProgress == 1.0)
    }
}
