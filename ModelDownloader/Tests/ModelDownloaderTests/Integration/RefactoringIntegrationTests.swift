import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Integration tests for the refactored ModelDownloader components
@Suite("Refactoring Integration Tests")
struct RefactoringIntegrationTests {
    @Test("All refactored components integrate correctly")
    func testComponentIntegration() async throws {
        // 1. Create all components
        let taskManager: DownloadTaskManager = DownloadTaskManager()
        let identityService: ModelIdentityService = ModelIdentityService()
        let mockDownloader: MockStreamingDownloaderForCoordinator = MockStreamingDownloaderForCoordinator()
        let mockFileManager: MockFileManagerForCoordinator = MockFileManagerForCoordinator()

        // Create coordinator with all dependencies
        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: taskManager,
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: mockFileManager
        )

        // 2. Test model identity resolution
        let location: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        let modelId: UUID = await identityService.generateModelId(for: location)

        // Verify consistent ID generation
        let modelId2: UUID = await identityService.generateModelId(for: location)
        #expect(modelId == modelId2)

        // 3. Create a SendableModel
        let model: SendableModel = SendableModel(
            id: modelId,
            ramNeeded: 8_000_000_000, // 8GB
            modelType: .language,
            location: location,
            architecture: .llama,
            backend: SendableModel.Backend.mlx
        )

        // 4. Configure mock for successful download
        await mockDownloader.setProgressValues([0.1, 0.3, 0.5, 0.7, 0.9, 1.0])

        // 5. Start download using coordinator
        try await coordinator.start(model: model)

        // Wait for download to progress
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // 6. Check download status
        let status: DownloadStatus = await coordinator.state(for: location)
        if case .downloading = status {
            // Download is in progress as expected
        } else if case .completed = status {
            // Download completed quickly
        } else {
            Issue.record("Unexpected status: \(status)")
        }

        // 7. Test task management
        let isDownloading: Bool = await taskManager.isDownloading(repositoryId: location)
        #expect(isDownloading == true || status == .completed)

        // 8. Test pause/resume
        if case .downloading = status {
            // Pause the download
            try await coordinator.pause(repositoryId: location)

            let pausedStatus: DownloadStatus = await coordinator.state(for: location)
            if case .paused = pausedStatus {
                // Successfully paused

                // Resume the download
                try await coordinator.resume(repositoryId: location)

                let resumedStatus: DownloadStatus = await coordinator.state(for: location)
                if case .downloading = resumedStatus {
                    // Successfully resumed
                } else {
                    Issue.record("Expected downloading status after resume")
                }
            } else {
                Issue.record("Expected paused status after pause")
            }
        }

        // 9. Cancel and cleanup
        await coordinator.cancel(repositoryId: location)

        // Verify cleanup
        let finalStatus: DownloadStatus = await coordinator.state(for: location)
        #expect(finalStatus == .notStarted)

        let hasTask: Bool = await taskManager.isDownloading(repositoryId: location)
        #expect(hasTask == false)
    }

    @Test("ModelActionState correctly maps download and availability states")
    func testModelActionStateMapping() {
        // Test download states
        let downloadNotStarted: DownloadStatus = DownloadStatus.notStarted
        let downloadProgress: DownloadStatus = DownloadStatus.downloading(progress: 0.5)
        let downloadPaused: DownloadStatus = DownloadStatus.paused(progress: 0.3)
        let downloadCompleted: DownloadStatus = DownloadStatus.completed
        let downloadFailed: DownloadStatus = DownloadStatus.failed(error: "Network error")

        // Test availability states  
        let availNotReady: ModelAvailability = ModelAvailability.notReady
        let availLoading: ModelAvailability = ModelAvailability.loading(progress: 0.7)
        let availReady: ModelAvailability = ModelAvailability.ready
        _ = ModelAvailability.generating
        _ = ModelAvailability.error("Memory error")

        // Map to action states
        let actionAvailable: ModelActionState = ModelActionState.from(
            download: downloadNotStarted,
            availability: availNotReady
        )
        #expect(actionAvailable == .available)
        #expect(actionAvailable.primaryAction == ModelAction.download)

        let actionDownloading: ModelActionState = ModelActionState.from(
            download: downloadProgress,
            availability: availNotReady
        )
        #expect(actionDownloading == .downloading(progress: 0.5))
        #expect(actionDownloading.primaryAction == ModelAction.pause)

        let actionPaused: ModelActionState = ModelActionState.from(
            download: downloadPaused,
            availability: availNotReady
        )
        #expect(actionPaused == .paused(progress: 0.3))
        #expect(actionPaused.primaryAction == ModelAction.resume)

        let actionLoading: ModelActionState = ModelActionState.from(
            download: downloadCompleted,
            availability: availLoading
        )
        #expect(actionLoading == .loading(progress: 0.7))
        #expect(actionLoading.primaryAction == nil) // No action while loading

        let actionReady: ModelActionState = ModelActionState.from(
            download: downloadCompleted,
            availability: availReady
        )
        #expect(actionReady == .ready)
        #expect(actionReady.primaryAction == ModelAction.open)

        let actionError: ModelActionState = ModelActionState.from(
            download: downloadFailed,
            availability: availNotReady
        )
        if case .error(let message) = actionError {
            #expect(message == "Network error")
            #expect(actionError.primaryAction == ModelAction.retry)
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test("Error handling with retryable errors")
    func testRetryableErrorHandling() {
        // Test retryable errors
        let networkError: ModelDownloadError = ModelDownloadError.networkError(
            NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        )
        #expect(networkError.isRetryable == true)

        let cancelledError: ModelDownloadError = ModelDownloadError.downloadCancelled
        #expect(cancelledError.isRetryable == true)

        let checksumError: ModelDownloadError = ModelDownloadError.checksumMismatch(
            expected: "abc123",
            actual: "def456"
        )
        #expect(checksumError.isRetryable == true)

        // Test non-retryable errors
        let invalidURLError: ModelDownloadError = ModelDownloadError.invalidURL("bad://url")
        #expect(invalidURLError.isRetryable == false)

        let modelNotFoundError: ModelDownloadError = ModelDownloadError.modelNotFound(UUID())
        #expect(modelNotFoundError.isRetryable == false)

        let insufficientStorageError: ModelDownloadError = ModelDownloadError.insufficientStorage(
            required: 1_000,
            available: 500
        )
        #expect(insufficientStorageError.isRetryable == false)
    }

    @Test("Identity service handles edge cases")
    func testIdentityServiceEdgeCases() async {
        let identityService: ModelIdentityService = ModelIdentityService()

        // Test various location formats
        let locations: [String] = [
            "author/model",
            "author/model-name-with-dashes",
            "mlx-community/Llama-3.2-3B-Instruct-4bit",
            "Author/Model", // Different case
            "author/model/" // Trailing slash
        ]

        for location: String in locations {
            let id: UUID = await identityService.generateModelId(for: location)
            let id2: UUID = await identityService.generateModelId(for: location)
            #expect(id == id2, "ID should be consistent for: \(location)")
        }

        // Test that different locations produce different IDs
        let id1: UUID = await identityService.generateModelId(for: "author/model1")
        let id2: UUID = await identityService.generateModelId(for: "author/model2")
        #expect(id1 != id2)

        // Test case insensitivity
        let idLower: UUID = await identityService.generateModelId(for: "author/model")
        let idUpper: UUID = await identityService.generateModelId(for: "AUTHOR/MODEL")
        #expect(idLower == idUpper)
    }
}
