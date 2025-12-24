import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("Local Model Import Tests")
internal struct LocalModelImportTests {
    // MARK: - Helpers

    private func createTestDatabase() throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        return try Database.new(configuration: config)
    }

    @Test("Adds local GGUF model and persists location")
    @MainActor
    func addsLocalGGUFModel() async throws {
        let database: Database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let viewModel: ModelDownloaderViewModel = ModelDownloaderViewModel(
            database: database,
            modelDownloader: MockModelDownloader(),
            communityExplorer: MockCommunityModelsExplorer()
        )

        let localPath: String = "/tmp/local-model.gguf"
        let modelId: UUID? = await viewModel.addLocalModel(
            LocalModelImport(
                name: "Local GGUF",
                backend: .gguf,
                type: .language,
                parameters: 1,
                ramNeeded: 123,
                size: 456,
                locationLocal: localPath,
                locationBookmark: nil
            )
        )

        #expect(modelId != nil)

        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        let saved: SendableModel? = models.first { model in
            model.locationKind == .localFile && model.locationLocal == localPath
        }
        #expect(saved != nil)
        #expect(saved?.backend == .gguf)
    }
}
