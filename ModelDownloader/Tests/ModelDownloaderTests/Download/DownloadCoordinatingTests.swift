import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("DownloadCoordinating Protocol Tests")
struct DownloadCoordinatingTests {
    // Mock implementations
    actor MockDownloadCoordinator: DownloadCoordinating {
        var startCalled: Bool = false
        var pauseCalled: Bool = false
        var resumeCalled: Bool = false
        var cancelCalled: Bool = false
        var stateCalled: Bool = false

        var mockState: DownloadStatus = .notStarted
        var mockError: Error?

        func start(model _: SendableModel) async throws {
            await Task.yield()
            startCalled = true
            if let error = mockError {
                throw error
            }
        }

        func pause(repositoryId _: String) async throws {
            await Task.yield()
            pauseCalled = true
            if let error = mockError {
                throw error
            }
        }

        func resume(repositoryId _: String) async throws {
            await Task.yield()
            resumeCalled = true
            if let error = mockError {
                throw error
            }
        }

        func cancel(repositoryId _: String) async {
            await Task.yield()
            cancelCalled = true
        }

        func state(for _: String) async -> DownloadStatus {
            await Task.yield()
            stateCalled = true
            return mockState
        }

        // Helper methods for the mock
        func setMockState(_ state: DownloadStatus) {
            mockState = state
        }

        func setMockError(_ error: Error) {
            mockError = error
        }
    }

    @Test("Coordinator can start download")
    func testStartDownload() async throws {
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let model: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 2_000,
            modelType: .language,
            location: "test/model",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        try await coordinator.start(model: model)

        #expect(await coordinator.startCalled == true)
    }

    @Test("Coordinator can pause download")
    func testPauseDownload() async throws {
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let repositoryId: String = "test/model"

        try await coordinator.pause(repositoryId: repositoryId)

        #expect(await coordinator.pauseCalled == true)
    }

    @Test("Coordinator can resume download")
    func testResumeDownload() async throws {
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let repositoryId: String = "test/model"

        try await coordinator.resume(repositoryId: repositoryId)

        #expect(await coordinator.resumeCalled == true)
    }

    @Test("Coordinator can cancel download")
    func testCancelDownload() async {
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let repositoryId: String = "test/model"

        await coordinator.cancel(repositoryId: repositoryId)

        #expect(await coordinator.cancelCalled == true)
    }

    @Test("Coordinator can check download state")
    func testCheckState() async {
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let repositoryId: String = "test/model"

        await coordinator.setMockState(.downloading(progress: 0.5))
        let state: DownloadStatus = await coordinator.state(for: repositoryId)

        #expect(await coordinator.stateCalled == true)
        if case .downloading(let progress) = state {
            #expect(progress == 0.5)
        } else {
            Issue.record("Expected downloading state")
        }
    }

    @Test("Coordinator handles errors during start")
    func testStartError() async {
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let model: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 2_000,
            modelType: .language,
            location: "test/model",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        let testError: ModelDownloadError = ModelDownloadError.networkError(NSError(domain: "test", code: -1))
        await coordinator.setMockError(testError)

        do {
            try await coordinator.start(model: model)
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is ModelDownloadError)
        }
    }

    @Test("Coordinator handles errors during pause")
    func testPauseError() async {
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let repositoryId: String = "test/model"

        let testError: ModelDownloadError = ModelDownloadError.unknown("Invalid state")
        await coordinator.setMockError(testError)

        do {
            try await coordinator.pause(repositoryId: repositoryId)
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is ModelDownloadError)
        }
    }
}

// Test for a concrete implementation
@Suite("DefaultDownloadCoordinator Tests")
struct DefaultDownloadCoordinatorTests {
    @Test("Coordinator initializes with dependencies")
    func testInitialization() async {
        let taskManager: DownloadTaskManager = DownloadTaskManager()
        let identityService: ModelIdentityService = ModelIdentityService()
        let mockDownloader: MockStreamingDownloaderForCoordinator = MockStreamingDownloaderForCoordinator()
        let mockFileManager: MockFileManagerForCoordinator = MockFileManagerForCoordinator()

        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: taskManager,
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: mockFileManager,
            modelFilesProvider: makeModelFilesProvider()
        )

        // Test initial state
        let state: DownloadStatus = await coordinator.state(for: "test/model")
        #expect(state == .notStarted)
    }

    @Test("Start download creates task and tracks it")
    func testStartCreatesTask() async throws {
        let taskManager: DownloadTaskManager = DownloadTaskManager()
        let identityService: ModelIdentityService = ModelIdentityService()
        let mockDownloader: MockStreamingDownloaderForCoordinator = MockStreamingDownloaderForCoordinator()
        let mockFileManager: MockFileManagerForCoordinator = MockFileManagerForCoordinator()

        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: taskManager,
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: mockFileManager,
            modelFilesProvider: makeModelFilesProvider()
        )

        let model: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 2_000,
            modelType: .language,
            location: "test/model",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        // Configure mock to succeed
        await mockDownloader.setProgressValues([0.5, 1.0])

        try await coordinator.start(model: model)

        // Wait a bit for the task to be created
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Verify task was created
        let hasTask: Bool = await taskManager.isDownloading(repositoryId: model.location)
        #expect(hasTask == true)
    }

    @Test("Pause updates state correctly")
    func testPauseUpdatesState() async throws {
        let taskManager: DownloadTaskManager = DownloadTaskManager()
        let identityService: ModelIdentityService = ModelIdentityService()
        let mockDownloader: MockStreamingDownloaderForCoordinator = MockStreamingDownloaderForCoordinator()
        let mockFileManager: MockFileManagerForCoordinator = MockFileManagerForCoordinator()

        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: taskManager,
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: mockFileManager,
            modelFilesProvider: makeModelFilesProvider()
        )

        let model: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 2_000,
            modelType: .language,
            location: "test/model",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        // Configure mock to emit multiple progress updates
        await mockDownloader.setProgressValues([0.1, 0.2, 0.3, 0.4, 0.5, 0.6])

        // Start download
        try await coordinator.start(model: model)

        // Wait for download to enter downloading state
        var state: DownloadStatus = await coordinator.state(for: model.location)
        var attempts: Int = 0
        while !state.isDownloading, attempts < 20 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            state = await coordinator.state(for: model.location)
            attempts += 1
        }

        // Pause the download
        try await coordinator.pause(repositoryId: model.location)

        // Check state is now paused
        attempts = 0
        state = await coordinator.state(for: model.location)
        while !state.isPaused, attempts < 20 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            state = await coordinator.state(for: model.location)
            attempts += 1
        }

        #expect(state.isPaused)
        if case .paused(let progress) = state {
            // Progress should be around 0.5 or less
            #expect(progress >= 0.0 && progress <= 1.0)
        } else {
            Issue.record("Expected paused state but got \(state)")
        }

        // Clean up to avoid lingering tasks
        await coordinator.cancel(repositoryId: model.location)
    }

    @Test("Cancel removes task and resets state")
    func testCancelCleansUp() async throws {
        let taskManager: DownloadTaskManager = DownloadTaskManager()
        let identityService: ModelIdentityService = ModelIdentityService()
        let mockDownloader: MockStreamingDownloaderForCoordinator = MockStreamingDownloaderForCoordinator()
        let mockFileManager: MockFileManagerForCoordinator = MockFileManagerForCoordinator()

        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: taskManager,
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: mockFileManager,
            modelFilesProvider: makeModelFilesProvider()
        )

        let model: SendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 2_000,
            modelType: .language,
            location: "test/model",
            architecture: .unknown,
            backend: SendableModel.Backend.mlx,
            locationKind: .huggingFace
        )

        // Start a download with slow progress
        await mockDownloader.setProgressValues([0.1, 0.2, 0.3, 0.4, 0.5])

        try await coordinator.start(model: model)

        // Wait a bit for the download to start
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms

        // Cancel the download
        await coordinator.cancel(repositoryId: model.location)

        // Wait longer for cancellation to complete and state to reset
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify task was removed
        let hasTask: Bool = await taskManager.isDownloading(repositoryId: model.location)
        #expect(hasTask == false)

        // Verify state is reset (could be .notStarted or .failed due to cancellation)
        let state: DownloadStatus = await coordinator.state(for: model.location)
        let stateIsReset: Bool
        switch state {
        case .notStarted, .failed:
            stateIsReset = true

        default:
            stateIsReset = false
        }
        #expect(stateIsReset, "Expected state to be .notStarted or .failed after cancellation, but got: \(state)")
    }
}

// Mock implementations for testing
actor MockStreamingDownloaderForCoordinator: StreamingDownloaderProtocol {
    var downloadResult: URL?
    var downloadError: Error?
    var pauseCalled: Bool = false
    var resumeCalled: Bool = false
    var cancelCalled: Bool = false
    var progressValues: [Double] = []
    private var isPaused: Bool = false
    private var isCancelled: Bool = false
    private var pauseContinuations: [CheckedContinuation<Void, Never>] = []

    func setProgressValues(_ values: [Double]) {
        progressValues = values
    }

    func setDownloadError(_ error: Error?) {
        downloadError = error
    }

    func download(
        from _: URL,
        to destination: URL,
        headers _: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        // Simulate progress updates
        for progress in progressValues {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            if isCancelled {
                throw CancellationError()
            }

            if isPaused {
                await waitWhilePaused()
            }

            progressHandler(progress)
        }

        if let error = downloadError {
            throw error
        }

        return downloadResult ?? destination
    }

    func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        try await download(from: url, to: destination, headers: headers, progressHandler: progressHandler)
    }

    func cancel(url _: URL) {
        cancelCalled = true
        isCancelled = true
        resumePausedDownloads()
    }

    func cancelAll() {
        // Not used in tests
    }

    func pause(url _: URL) {
        pauseCalled = true
        isPaused = true
    }

    func pauseAll() {
        // Not used in tests
    }

    func resume(url _: URL) {
        resumeCalled = true
        isPaused = false
        resumePausedDownloads()
    }

    func resumeAll() {
        // Not used in tests
    }

    private func waitWhilePaused() async {
        while isPaused, !isCancelled {
            await withCheckedContinuation { continuation in
                pauseContinuations.append(continuation)
            }
        }
    }

    private func resumePausedDownloads() {
        guard !pauseContinuations.isEmpty else { return }
        let continuations: [CheckedContinuation<Void, Never>] = pauseContinuations
        pauseContinuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }
}

actor MockFileManagerForCoordinator: ModelFileManagerProtocol {
    nonisolated func modelDirectory(for repositoryId: String, backend: SendableModel.Backend) -> URL {
        let safeRepoId: String = repositoryId.replacingOccurrences(of: "/", with: "_")
        return URL(fileURLWithPath: "/tmp/models/\(backend.rawValue)/\(safeRepoId)")
    }

    func listDownloadedModels() -> [ModelInfo] {
        []
    }

    func modelExists(repositoryId _: String) -> Bool {
        false
    }

    func deleteModel(repositoryId _: String) {
        // No-op for tests
    }

    func moveModel(from _: URL, to _: URL) {
        // No-op for tests
    }

    func getModelSize(repositoryId _: String) -> Int64? {
        nil
    }

    func hasEnoughSpace(for _: Int64) -> Bool {
        true
    }

    nonisolated func temporaryDirectory(for repositoryId: String) -> URL {
        let safeDirName: String = repositoryId.replacingOccurrences(of: "/", with: "_")
        return URL(fileURLWithPath: "/tmp/downloads/\(safeDirName)")
    }

    func finalizeDownload(
        repositoryId: String,
        name: String,
        backend: SendableModel.Backend,
        from tempURL: URL,
        totalSize: Int64
    ) async -> ModelInfo {
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

    func cleanupIncompleteDownloads() {
        // No-op for tests
    }

    func availableDiskSpace() -> Int64? {
        1_000_000_000 // 1GB
    }
}
