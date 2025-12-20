@testable import Abstractions
@testable import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("ModelDownloaderViewModel Background Completion Error Tests")
internal struct BackgroundCompletionErrorTests {
    // MARK: - Test Helpers

    @MainActor
    private func setupFailedDownloadModel() async throws -> (Database, UUID, String) {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory()
        )
        let database: Database = try Database.new(configuration: config)
        let sessionIdentifier: String = "test-session-failed"

        // Create a model using ModelDTO
        let modelDTO: ModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "failed-model",
            displayName: "Failed Model",
            displayDescription: "Test model for failed download",
            skills: ["text generation"],
            parameters: 1_000_000_000,
            ramNeeded: 1_000,
            size: 5_000,
            locationHuggingface: "test/location",
            version: 1,
            architecture: .llama
        )

        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let model: Model = try await database.read(ModelCommands.GetModel(name: "failed-model"))

        // Update model state to downloading
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: model.id,
            progress: 0.5
        ))

        return (database, model.id, sessionIdentifier)
    }

    private func createMockDownloaderWithError(
        modelId: UUID,
        sessionIdentifier: String,
        error: NSError
    ) -> MockModelDownloader {
        let mockDownloader: MockModelDownloader = MockModelDownloader()
        mockDownloader.backgroundDownloadStatusToReturn = [
            BackgroundDownloadStatus(
                handle: BackgroundDownloadHandle(
                    id: modelId,
                    modelId: "failed-model",
                    backend: .mlx,
                    sessionIdentifier: sessionIdentifier
                ),
                state: .failed,
                progress: 0.5,
                error: error,
                estimatedTimeRemaining: nil
            )
        ]
        return mockDownloader
    }

    @Test("ViewModel handles failed background downloads")
    @MainActor
    func testFailedBackgroundDownload() async throws {
        // Given
        let (database, modelId, sessionIdentifier): (Database, UUID, String) = try await setupFailedDownloadModel()
        let downloadError: NSError = NSError(domain: "TestError", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Network connection lost"
        ])
        let mockDownloader: MockModelDownloader = createMockDownloaderWithError(
            modelId: modelId,
            sessionIdentifier: sessionIdentifier,
            error: downloadError
        )

        let viewModel: ModelDownloaderViewModel = ModelDownloaderViewModel(
            database: database,
            modelDownloader: mockDownloader,
            communityExplorer: MockCommunityModelsExplorer()
        )

        // When
        await viewModel.handleBackgroundDownloadCompletion(
            identifier: sessionIdentifier
        ) {
                // No completion action needed for this test
        }

        // Then
        let model: Model = try await database.read(ModelCommands.GetModelFromId(id: modelId))
        #expect(model.state == .notDownloaded)
    }

    @Test("ViewModel handles network errors gracefully")
    @MainActor
    func testNetworkErrorHandling() async throws {
        // Given
        let (database, modelId, sessionIdentifier): (Database, UUID, String) = try await setupNetworkErrorModel()
        let networkError: NSError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )

        let mockDownloader: MockModelDownloader = createMockDownloaderWithNetworkError(
            modelId: modelId,
            sessionIdentifier: sessionIdentifier,
            error: networkError
        )

        let viewModel: ModelDownloaderViewModel = ModelDownloaderViewModel(
            database: database,
            modelDownloader: mockDownloader,
            communityExplorer: MockCommunityModelsExplorer()
        )

        // When
        await viewModel.handleBackgroundDownloadCompletion(
            identifier: sessionIdentifier
        ) {
                // No completion action needed for this test
        }

        // Then
        let model: Model = try await database.read(ModelCommands.GetModelFromId(id: modelId))
        #expect(model.state == .notDownloaded)
    }

    @MainActor
    private func setupNetworkErrorModel() async throws -> (Database, UUID, String) {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory()
        )
        let database: Database = try Database.new(configuration: config)
        let sessionIdentifier: String = "test-session-network-error"

        // Create a model using ModelDTO
        let modelDTO: ModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "network-error-model",
            displayName: "Network Error Model",
            displayDescription: "Test model for network error",
            skills: ["text generation"],
            parameters: 1_000_000_000,
            ramNeeded: 1_000,
            size: 5_000,
            locationHuggingface: "test/location",
            version: 1,
            architecture: .llama
        )

        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let model: Model = try await database.read(ModelCommands.GetModel(name: "network-error-model"))

        // Update model state to downloading
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: model.id,
            progress: 0.8
        ))

        return (database, model.id, sessionIdentifier)
    }

    private func createMockDownloaderWithNetworkError(
        modelId: UUID,
        sessionIdentifier: String,
        error: NSError
    ) -> MockModelDownloader {
        let mockDownloader: MockModelDownloader = MockModelDownloader()
        mockDownloader.backgroundDownloadStatusToReturn = [
            BackgroundDownloadStatus(
                handle: BackgroundDownloadHandle(
                    id: modelId,
                    modelId: "network-error-model",
                    backend: .mlx,
                    sessionIdentifier: sessionIdentifier
                ),
                state: .failed,
                progress: 0.8,
                error: error,
                estimatedTimeRemaining: nil
            )
        ]
        return mockDownloader
    }
}
