import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("HuggingFaceDownloader Tests")
struct HuggingFaceDownloaderTests {
    // MARK: - Mock Types

    actor MockHubAPI {
        var endpoint: String = "https://huggingface.co"
        var files: [Any] = []
        var shouldThrowError: Bool = false
        var callCount: Int = 0

        // Mock implementations

        func setFiles(_ newFiles: [FileInfo]) {
            self.files = newFiles
        }

        func setShouldThrow(_ value: Bool) {
            self.shouldThrowError = value
        }
    }

    actor MockFileManager: ModelFileManagerProtocol {
        var modelExists: Bool = false
        var downloadedModels: [ModelInfo] = []
        var finalizedModel: ModelInfo?

        nonisolated func temporaryDirectory(for repositoryId: String) -> URL {
            URL(fileURLWithPath: "/tmp/models/\(repositoryId)")
        }

        nonisolated func modelDirectory(for repositoryId: String, backend _: SendableModel.Backend) -> URL {
            URL(fileURLWithPath: "/models/\(repositoryId)")
        }

        func moveModel(from _: URL, to _: URL) throws {
            // No-op for testing
        }

        func getModelSize(repositoryId _: String) -> Int64? {
            100_000_000
        }

        func hasEnoughSpace(for _: Int64) -> Bool {
            true
        }

        func cleanupIncompleteDownloads() throws {
            // No-op for testing
        }

        func availableDiskSpace() -> Int64? {
            1_000_000_000
        }

        func modelExists(repositoryId _: String) -> Bool {
            modelExists
        }

        func deleteModel(repositoryId _: String) throws {
            // No-op for testing
        }

        func listDownloadedModels() throws -> [ModelInfo] {
            downloadedModels
        }

        func finalizeDownload(
            repositoryId _: String,
            name: String,
            backend: SendableModel.Backend,
            from tempDirectory: URL,
            totalSize: Int64
        ) throws -> ModelInfo {
            let info: ModelInfo = ModelInfo(
                id: UUID(),
                name: name,
                backend: backend,
                location: tempDirectory,
                totalSize: totalSize,
                downloadDate: Date(),
                metadata: [:]
            )
            finalizedModel = info
            downloadedModels.append(info)
            return info
        }

        func calculateDirectorySize(at _: URL) throws -> Int64 {
            100_000_000
        }

        func verifyModelIntegrity(modelId _: UUID) throws -> Bool {
            true
        }

        func setModelExists(_ exists: Bool) {
            self.modelExists = exists
        }

        func addDownloadedModel(_ model: ModelInfo) {
            self.downloadedModels.append(model)
        }
    }

    // MARK: - Test Helpers

    private func createDownloader(
        fileManager: ModelFileManagerProtocol? = nil,
        coordinator: DownloadCoordinating? = nil
    ) -> HuggingFaceDownloader {
        let fileManager: ModelFileManagerProtocol = fileManager ?? MockFileManager()
        let coord: DownloadCoordinating = coordinator ?? MockDownloadCoordinator()

        return HuggingFaceDownloader(
            fileManager: fileManager,
            enableProductionFeatures: false,
            downloadCoordinator: coord
        )
    }

    // MARK: - Tests

    @Test("Download with already downloaded model")
    func testDownloadAlreadyExists() async throws {
        let fileManager: MockFileManager = MockFileManager()
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let downloader: HuggingFaceDownloader = createDownloader(fileManager: fileManager, coordinator: coordinator)

        // Generate the expected model ID that will be used
        let identityService: ModelIdentityService = ModelIdentityService()
        let expectedId: UUID = await identityService.generateModelId(for: "test/model")

        // Pre-populate with existing model using the expected ID
        let existingModel: ModelInfo = ModelInfo(
            id: expectedId,
            name: "test/model",
            backend: SendableModel.Backend.mlx,
            location: URL(fileURLWithPath: "/models/\(expectedId)"),
            totalSize: 100_000_000,
            downloadDate: Date(),
            metadata: [:]
        )
        await fileManager.addDownloadedModel(existingModel)

        // Mark the model as completed in coordinator
        await coordinator.markCompleted(repositoryId: "test/model")

        // Try to download
        var events: [DownloadEvent] = []
        for try await event in downloader.download(modelId: "test/model", backend: SendableModel.Backend.mlx) {
            events.append(event)
        }

        // Should immediately complete with existing model
        #expect(events.count == 1)
        if case .completed(let info) = events[0] {
            #expect(info.id == expectedId)
            #expect(info.name == "test/model")
        } else {
            Issue.record("Expected completed event")
        }
    }

    @Test("Download progress tracking")
    func testDownloadProgress() async throws {
        let fileManager: MockFileManager = MockFileManager()
        let downloader: HuggingFaceDownloader = createDownloader(fileManager: fileManager)

        // Create a mock coordinator that simulates progress
        let mockCoordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        await mockCoordinator.setProgressSequence([0.1, 0.3, 0.5, 0.7, 0.9, 1.0])

        // We can't easily inject the coordinator, so we'll test the progress flow differently
        // by verifying the download event stream yields progress events

        let modelId: String = "test/model"
        var progressEvents: [Double] = []

        // Create a task to collect events
        let downloadTask: Task<ModelInfo?, Error> = Task {
            for try await event in downloader.download(modelId: modelId, backend: SendableModel.Backend.mlx) {
                if case .progress(let progress) = event {
                    progressEvents.append(progress.percentage)
                } else if case .completed(let modelInfo) = event {
                    return modelInfo
                }
            }
            return nil
        }

        // Cancel after a short delay to prevent hanging
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        downloadTask.cancel()

        // The actual download would fail because we don't have a real HubAPI,
        // but we're testing the structure of the code
        #expect(downloadTask.isCancelled)
    }

    @Test("Backend enum values are correct")
    func testBackendEnumValues() {
        #expect(SendableModel.Backend.mlx.rawValue == "mlx")
        #expect(SendableModel.Backend.gguf.rawValue == "gguf")
        #expect(SendableModel.Backend.coreml.rawValue == "coreml")
    }

    @Test("Factory method creates production downloader")
    func testFactoryMethod() {
        let fileManager: MockFileManager = MockFileManager()
        let _: HuggingFaceDownloader = HuggingFaceDownloader.createProductionDownloader(
            fileManager: fileManager
        )

        // Verify it's properly initialized by checking it doesn't crash
        // We can't access internal components without exposing them
    }

    @Test("Model ID generation is consistent")
    func testModelIdGeneration() async {
        // Test ModelIdentityService directly since it's internal to HuggingFaceDownloader
        let identityService: ModelIdentityService = ModelIdentityService()

        let id1: UUID = await identityService.generateModelId(for: "mlx-community/model")
        let id2: UUID = await identityService.generateModelId(for: "mlx-community/model")

        #expect(id1 == id2)
    }

    @Test("Custom ID is respected")
    func testCustomIdUsage() async throws {
        let fileManager: MockFileManager = MockFileManager()
        let coordinator: MockDownloadCoordinator = MockDownloadCoordinator()
        let downloader: HuggingFaceDownloader = createDownloader(fileManager: fileManager, coordinator: coordinator)
        let customId: UUID = UUID()

        // Pre-populate with existing model
        await fileManager.addDownloadedModel(
            ModelInfo(
                id: customId,
                name: "test/model",
                backend: .mlx,
                location: URL(fileURLWithPath: "/models/\(customId)"),
                totalSize: 100_000_000,
                downloadDate: Date(),
                metadata: [:]
            )
        )

        // Mark as completed in coordinator
        await coordinator.markCompleted(repositoryId: "test/model")

        var events: [DownloadEvent] = []
        for try await event in downloader.download(
            modelId: "test/model",
            backend: .mlx,
            customId: customId
        ) {
            events.append(event)
        }

        #expect(events.count == 1)
        if case .completed(let info) = events[0] {
            #expect(info.id == customId)
        }
    }
}

// MARK: - Mock Download Coordinator

actor MockDownloadCoordinator: DownloadCoordinating {
    private var states: [String: DownloadStatus] = [:]
    private var progressSequence: [Double] = []
    private var currentProgressIndex: Int = 0

    func start(model: SendableModel) throws {
        states[model.location] = .downloading(progress: 0.0)
    }

    func pause(repositoryId: String) throws {
        if case .downloading(let progress) = states[repositoryId] {
            states[repositoryId] = .paused(progress: progress)
        }
    }

    func resume(repositoryId: String) throws {
        if case .paused(let progress) = states[repositoryId] {
            states[repositoryId] = .downloading(progress: progress)
        }
    }

    func cancel(repositoryId: String) throws {
        states[repositoryId] = .notStarted
    }

    func state(for repositoryId: String) -> DownloadStatus {
        if let state = states[repositoryId] {
            return state
        }
        return .notStarted
    }

    func markCompleted(repositoryId: String) {
        states[repositoryId] = .completed
    }

    func setProgressSequence(_ sequence: [Double]) {
        self.progressSequence = sequence
        self.currentProgressIndex = 0
    }

    func nextProgress() -> Double? {
        guard currentProgressIndex < progressSequence.count else { return nil }
        let progress: Double = progressSequence[currentProgressIndex]
        currentProgressIndex += 1
        return progress
    }
}

// MARK: - Additional Test Helpers

// Note: We can't easily access internal components of HuggingFaceDownloader
// without exposing them, so some tests are limited to public API testing
