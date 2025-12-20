@testable import Abstractions
@testable import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("ModelDownloaderViewModel Background Completion Tests")
internal struct BackgroundCompletionTests {
    @Test("ViewModel updates model state on background completion")
    @MainActor
    func testViewModelUpdatesModelState() async throws {
        // Given
        let (database, modelId, sessionIdentifier): (Database, UUID, String) = try await setupSingleDownloadModel()
        let mockDownloader: MockModelDownloader = createMockDownloaderWithCompletion(
            modelId: modelId,
            sessionIdentifier: sessionIdentifier
        )
        let viewModel: ModelDownloaderViewModel = createViewModel(database: database, downloader: mockDownloader)

        actor CompletionTracker {
            var completed: Bool = false

            func markCompleted() { completed = true }
        }

        let tracker: CompletionTracker = CompletionTracker()

        // When
        await viewModel.handleBackgroundDownloadCompletion(
            identifier: sessionIdentifier
        ) { Task { await tracker.markCompleted() } }

        // Then
        #expect(await tracker.completed == true)
        let model: Model = try await database.read(ModelCommands.GetModelFromId(id: modelId))
        #expect(model.state == .downloaded)
        #expect(mockDownloader.handleBackgroundDownloadCompletionCalled == true)
        #expect(mockDownloader.lastCompletionIdentifier == sessionIdentifier)
    }

    @Test("ViewModel handles multiple downloads in background session")
    @MainActor
    func testMultipleDownloadsInSession() async throws {
        // Given
        let (database, modelIds, sessionIdentifier): (Database, [UUID], String) = try await setupMultipleDownloadModels()
        let mockDownloader: MockModelDownloader = createMockDownloaderWithMultipleCompletions(
            modelIds: modelIds,
            sessionIdentifier: sessionIdentifier
        )
        let viewModel: ModelDownloaderViewModel = createViewModel(database: database, downloader: mockDownloader)

        // When
        await viewModel.handleBackgroundDownloadCompletion(
            identifier: sessionIdentifier
        ) {
                // No completion action needed for this test
        }

        // Then
        for modelId in modelIds {
            let model: Model = try await database.read(ModelCommands.GetModelFromId(id: modelId))
            #expect(model.state == .downloaded)
        }
    }

    @Test("ViewModel ignores downloads from different session")
    @MainActor
    func testIgnoresDifferentSession() async throws {
        // Given
        let (database, modelId, _): (Database, UUID, String) = try await setupSingleDownloadModel()
        let correctSession: String = "correct-session"
        let wrongSession: String = "wrong-session"

        let mockDownloader: MockModelDownloader = createMockDownloaderWithCompletion(
            modelId: modelId,
            sessionIdentifier: wrongSession // Different session
        )
        let viewModel: ModelDownloaderViewModel = createViewModel(database: database, downloader: mockDownloader)

        // When - call with correct session
        await viewModel.handleBackgroundDownloadCompletion(
            identifier: correctSession
        ) {
                // No completion action needed for this test
        }

        // Then - model should NOT be updated since session doesn't match
        let model: Model = try await database.read(ModelCommands.GetModelFromId(id: modelId))
        // Model should still be in downloading state since the session didn't match
        if case .downloadingActive = model.state {
            // Expected state
        } else {
            Issue.record("Model state should still be downloadingActive but was \(model.state)")
        }
    }
}

// MARK: - Test Helpers

extension BackgroundCompletionTests {
    @MainActor
    private func setupSingleDownloadModel() async throws -> (Database, UUID, String) {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory()
        )
        let database: Database = try Database.new(configuration: config)
        let sessionIdentifier: String = "test-session-123"

        // Create a model using ModelDTO
        let modelDTO: ModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model",
            displayName: "Test Model",
            displayDescription: "Test model for download",
            skills: ["text generation"],
            parameters: 1_000_000_000,
            ramNeeded: 1_000,
            size: 5_000,
            locationHuggingface: "test/location",
            version: 1,
            architecture: .llama
        )

        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let model: Model = try await database.read(ModelCommands.GetModel(name: "test-model"))

        // Update model state to downloading
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: model.id,
            progress: 0.5
        ))

        return (database, model.id, sessionIdentifier)
    }

    private func createMockDownloaderWithCompletion(modelId: UUID, sessionIdentifier: String) -> MockModelDownloader {
        let mockDownloader: MockModelDownloader = MockModelDownloader()
        mockDownloader.backgroundDownloadStatusToReturn = [
            BackgroundDownloadStatus(
                handle: BackgroundDownloadHandle(
                    id: modelId,
                    modelId: "test-model",
                    backend: .mlx,
                    sessionIdentifier: sessionIdentifier
                ),
                state: .completed,
                progress: 1.0,
                error: nil,
                estimatedTimeRemaining: nil
            )
        ]
        return mockDownloader
    }

    private func createViewModel(database: Database, downloader: MockModelDownloader) -> ModelDownloaderViewModel {
        ModelDownloaderViewModel(
            database: database,
            modelDownloader: downloader,
            communityExplorer: MockCommunityModelsExplorer()
        )
    }

    @MainActor
    private func setupMultipleDownloadModels() async throws -> (Database, [UUID], String) {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory()
        )
        let database: Database = try Database.new(configuration: config)
        let sessionIdentifier: String = "test-session-multi"

        // Create first model
        let modelDTO1: ModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "model-1",
            displayName: "Model 1",
            displayDescription: "First test model",
            skills: ["text generation"],
            parameters: 1_000_000_000,
            ramNeeded: 1_000,
            size: 5_000,
            locationHuggingface: "test/location1",
            version: 1,
            architecture: .llama
        )

        // Create second model
        let modelDTO2: ModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "model-2",
            displayName: "Model 2",
            displayDescription: "Second test model",
            skills: ["text generation"],
            parameters: 2_000_000_000,
            ramNeeded: 2_000,
            size: 8_000,
            locationHuggingface: "test/location2",
            version: 1,
            architecture: .llama
        )

        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO1, modelDTO2]))

        let model1: Model = try await database.read(ModelCommands.GetModel(name: "model-1"))
        let model2: Model = try await database.read(ModelCommands.GetModel(name: "model-2"))

        // Update model states to downloading
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: model1.id,
            progress: 0.3
        ))
        try await database.write(ModelCommands.UpdateModelDownloadProgress(
            id: model2.id,
            progress: 0.7
        ))

        return (database, [model1.id, model2.id], sessionIdentifier)
    }

    private func createMockDownloaderWithMultipleCompletions(
        modelIds: [UUID],
        sessionIdentifier: String
    ) -> MockModelDownloader {
        let mockDownloader: MockModelDownloader = MockModelDownloader()
        mockDownloader.backgroundDownloadStatusToReturn = modelIds.enumerated().map { index, modelId in
            BackgroundDownloadStatus(
                handle: BackgroundDownloadHandle(
                    id: modelId,
                    modelId: "model-\(index + 1)",
                    backend: .mlx,
                    sessionIdentifier: sessionIdentifier
                ),
                state: .completed,
                progress: 1.0,
                error: nil,
                estimatedTimeRemaining: nil
            )
        }
        return mockDownloader
    }
}
