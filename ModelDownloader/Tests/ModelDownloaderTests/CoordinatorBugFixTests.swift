import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Focused unit tests for the DefaultDownloadCoordinator bug fix
@Suite("Coordinator Bug Fix Tests", .serialized)
struct CoordinatorBugFixTests {
    // MARK: - Test Doubles

    /// Minimal mock file manager that tracks finalization calls
    actor MockFileManagerForBugTest: ModelFileManagerProtocol {
        private var finalizeCallCount: Int = 0
        private var lastFinalizedRepositoryId: String?

        func getFinalizeCallCount() -> Int { finalizeCallCount }
        func getLastFinalizedRepositoryId() -> String? { lastFinalizedRepositoryId }

        // MARK: - Required Protocol Methods

        nonisolated func modelDirectory(for modelId: UUID, backend _: SendableModel.Backend) -> URL {
            URL(fileURLWithPath: "/mock/\(modelId)")
        }

        nonisolated func modelDirectory(for repositoryId: String, backend: SendableModel.Backend) -> URL {
            let safeName: String = repositoryId.replacingOccurrences(of: "/", with: "_")
            return URL(fileURLWithPath: "/mock/\(backend.rawValue)/\(safeName)")
        }

        func listDownloadedModels() -> [ModelInfo] { [] }
        func modelExists(repositoryId _: String) -> Bool { false }
        func deleteModel(repositoryId _: String) {}
        func moveModel(from _: URL, to _: URL) {}
        func getModelSize(repositoryId _: String) -> Int64? { nil }
        func hasEnoughSpace(for _: Int64) -> Bool { true }
        nonisolated func temporaryDirectory(for repositoryId: String) -> URL {
            let safeDirName: String = repositoryId.replacingOccurrences(of: "/", with: "_")
            return URL(fileURLWithPath: "/tmp/\(safeDirName)")
        }
        func cleanupIncompleteDownloads() {}
        func availableDiskSpace() -> Int64? { 1_000_000 }

        // MARK: - The Critical Methods We're Testing

        func finalizeDownload(
            repositoryId: String,
            name: String,
            backend: SendableModel.Backend,
            from tempURL: URL,
            totalSize: Int64
        ) async -> ModelInfo {
            finalizeCallCount += 1
            lastFinalizedRepositoryId = repositoryId

            // Generate deterministic UUID from repository ID for external compatibility
            let identityService: ModelIdentityService = ModelIdentityService()
            let modelId: UUID = await identityService.generateModelId(for: repositoryId)

            return ModelInfo(
                id: modelId,
                name: name,
                backend: backend,
                location: tempURL,
                totalSize: totalSize,
                downloadDate: Date(),
                metadata: [
                    "repositoryId": repositoryId,
                    "source": "huggingface",
                    "downloadType": "repository-based"
                ]
            )
        }
    }

    /// Mock streaming downloader that simulates successful download
    actor MockStreamingDownloaderForBugTest: StreamingDownloaderProtocol {
        func download(
            from _: URL,
            to destination: URL,
            headers _: [String: String],
            progressHandler: @Sendable (Double) -> Void
        ) async throws -> URL {
            // Simulate progress
            progressHandler(0.5)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            progressHandler(1.0)

            // Create mock downloaded file
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "mock downloaded content".write(to: destination, atomically: true, encoding: .utf8)

            return destination
        }

        func downloadResume(
            from url: URL,
            to destination: URL,
            headers: [String: String],
            progressHandler: @Sendable (Double) -> Void
        ) async throws -> URL {
            try await download(from: url, to: destination, headers: headers, progressHandler: progressHandler)
        }

        func cancel(url _: URL) {}
        func cancelAll() {}
        func pause(url _: URL) {}
        func pauseAll() {}
        func resume(url _: URL) {}
        func resumeAll() {}
    }

    // MARK: - Bug Fix Tests

    @Test("Bug #57 Fix: DefaultDownloadCoordinator calls finalizeDownload")
    func testCoordinatorCallsFinalizeDownload() async throws {
        // Given - Setup coordinator with mock dependencies
        let taskManager: DownloadTaskManager = DownloadTaskManager()
        let identityService: ModelIdentityService = ModelIdentityService()
        let mockFileManager: MockFileManagerForBugTest = MockFileManagerForBugTest()
        let mockDownloader: MockStreamingDownloaderForBugTest = MockStreamingDownloaderForBugTest()

        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: taskManager,
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: mockFileManager,
            modelFilesProvider: makeModelFilesProvider()
        )

        let testRepositoryId: String = "test/bug57-fix"
        let testModel: SendableModel = SendableModel(
            id: await identityService.generateModelId(for: testRepositoryId),
            ramNeeded: 1_000,
            modelType: .language,
            location: testRepositoryId,
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        // Verify finalization hasn't been called yet
        let initialCallCount: Int = await mockFileManager.getFinalizeCallCount()
        #expect(initialCallCount == 0)

        // When - Start download (this should call finalizeDownload on completion)
        try await coordinator.start(model: testModel)

        // Wait for download to complete
        var state: DownloadStatus = await coordinator.state(for: testModel.location)
        var attempts: Int = 0
        while !state.isCompleted, attempts < 40 {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            state = await coordinator.state(for: testModel.location)
            if case .failed = state {
                break
            }
            attempts += 1
        }

        // Then - Verify finalizeDownload was called (Bug #57 fix)
        let finalCallCount: Int = await mockFileManager.getFinalizeCallCount()
        let finalizedRepositoryId: String? = await mockFileManager.getLastFinalizedRepositoryId()

        #expect(finalCallCount > initialCallCount) // finalizeDownload was called
        #expect(finalizedRepositoryId == testRepositoryId) // Called with correct repository ID
        #expect(state.isCompleted) // Download completed successfully
    }

    @Test("Bug #57 Fix: Coordinator tracks state properly during finalization")
    func testCoordinatorStateTracking() async throws {
        // Given - Setup coordinator
        let taskManager: DownloadTaskManager = DownloadTaskManager()
        let identityService: ModelIdentityService = ModelIdentityService()
        let mockFileManager: MockFileManagerForBugTest = MockFileManagerForBugTest()
        let mockDownloader: MockStreamingDownloaderForBugTest = MockStreamingDownloaderForBugTest()

        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: taskManager,
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: mockFileManager,
            modelFilesProvider: makeModelFilesProvider()
        )

        let testModel: SendableModel = SendableModel(
            id: await identityService.generateModelId(for: "test/state-tracking"),
            ramNeeded: 1_000,
            modelType: .language,
            location: "test/state-tracking",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        // When - Start download and track state changes
        let initialState: DownloadStatus = await coordinator.state(for: testModel.location)
        #expect(initialState == .notStarted)

        try await coordinator.start(model: testModel)

        // Wait for completion while tracking states
        var downloadingStateFound: Bool = false
        var attempts: Int = 0

        while attempts < 20 {
            let currentState: DownloadStatus = await coordinator.state(for: testModel.location)

            if case .downloading = currentState {
                downloadingStateFound = true
            }

            if currentState.isCompleted {
                break
            }

            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        let finalState: DownloadStatus = await coordinator.state(for: testModel.location)

        // Then - Verify state transitions occurred properly
        #expect(downloadingStateFound) // Went through downloading state
        #expect(finalState.isCompleted) // Reached completed state

        // Verify finalization was called as part of completion
        let callCount: Int = await mockFileManager.getFinalizeCallCount()
        #expect(callCount > 0)
    }

    @Test("Shared identity service integration in coordinator")
    func testSharedIdentityServiceInCoordinator() async throws {
        // Given - Setup coordinator with shared identity service
        let sharedIdentityService: ModelIdentityService = ModelIdentityService()
        let mockFileManager: MockFileManagerForBugTest = MockFileManagerForBugTest()
        let mockDownloader: MockStreamingDownloaderForBugTest = MockStreamingDownloaderForBugTest()

        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: DownloadTaskManager(),
            identityService: sharedIdentityService,
            downloader: mockDownloader,
            fileManager: mockFileManager,
            modelFilesProvider: makeModelFilesProvider()
        )

        let testLocation: String = "test/shared-identity"

        // When - Create model using shared identity service
        let expectedUUID: UUID = await sharedIdentityService.generateModelId(for: testLocation)
        let testModel: SendableModel = SendableModel(
            id: expectedUUID,
            ramNeeded: 1_000,
            modelType: .language,
            location: testLocation,
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        try await coordinator.start(model: testModel)

        // Wait for completion
        var state: DownloadStatus = await coordinator.state(for: testModel.location)
        var attempts: Int = 0
        while !state.isCompleted, attempts < 20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            state = await coordinator.state(for: testModel.location)
            attempts += 1
        }

        // Then - Verify the coordinator used the correct UUID consistently
        #expect(state.isCompleted)
        #expect(testModel.id == expectedUUID) // Model has expected UUID

        // Verify finalization was called with repository-based approach
        let finalizedRepositoryId: String? = await mockFileManager.getLastFinalizedRepositoryId()
        #expect(finalizedRepositoryId == testLocation)
    }
}
