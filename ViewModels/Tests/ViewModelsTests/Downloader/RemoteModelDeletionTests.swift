import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("Remote Model Deletion Tests")
internal struct RemoteModelDeletionTests {
    @Test("Deleting a remote model removes it from the library")
    @MainActor
    func deletingRemoteModelRemovesRecord() async throws {
        let environment: WorkingTestEnvironment = try WorkingDownloadButtonTests.setupWorkingTestEnvironment()
        let viewModel: ModelDownloaderViewModel = environment.viewModel
        let database: Database = environment.database

        _ = try await database.execute(AppCommands.Initialize())

        let location: String = "openrouter:arcee-ai/trinity-large-preview:free"
        let remoteId: UUID = try await database.write(
            ModelCommands.CreateRemoteModel(
                name: "arcee-ai/trinity-large-preview:free",
                displayName: "Arcee Trinity Large Preview (free)",
                displayDescription: "Remote model for deletion test",
                location: location,
                type: .language,
                architecture: .gpt
            )
        )

        let before: Model? = try await database.read(ModelCommands.GetModelByLocation(location: location))
        try #require(before != nil)

        await viewModel.delete(modelId: remoteId)
        try await Task.sleep(nanoseconds: 150_000_000)

        let after: Model? = try await database.read(ModelCommands.GetModelByLocation(location: location))
        #expect(after == nil)
    }
}
