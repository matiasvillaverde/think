import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("Download Finalization Bug Fixes Tests")
struct DownloadFinalizationTests {
    @Test("DefaultDownloadCoordinator calls finalizeDownload on completion")
    func testCoordinatorFinalizesDownload() async throws {
        // Given
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Ensure clean state
        try? FileManager.default.removeItem(at: tempDir)

        // Create shared identity service for consistent UUIDs
        let identityService: ModelIdentityService = ModelIdentityService()

        // Create file manager with shared identity service
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: identityService
        )

        // Create mock streaming downloader that succeeds
        let mockDownloader: TestMockStreamingDownloader = TestMockStreamingDownloader()
        let testModelLocation: String = "mlx-community/test-model"
        let testModel: SendableModel = SendableModel(
            id: await identityService.generateModelId(for: testModelLocation),
            ramNeeded: 1_000,
            modelType: .language,
            location: testModelLocation,
            architecture: .unknown,
            backend: SendableModel.Backend.mlx
        )

        // Create coordinator
        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: DownloadTaskManager(),
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: fileManager
        )

        // When - Start download
        try await coordinator.start(model: testModel)

        // Wait for completion
        var state: DownloadStatus = await coordinator.state(for: testModel.location)
        var attempts: Int = 0
        while !state.isCompleted, attempts < 10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            state = await coordinator.state(for: testModel.location)
            attempts += 1
        }

        // Then - Download should be completed
        #expect(state.isCompleted)

        // And model should exist in file manager
        let modelExists: Bool = await fileManager.modelExists(repositoryId: testModelLocation)
        #expect(modelExists)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Test Bug #1 & #87: UUID Consistency

    @Test("Shared ModelIdentityService ensures UUID consistency")
    func testUUIDConsistencyBetweenComponents() async throws {
        // Given
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Create shared identity service
        let sharedIdentityService: ModelIdentityService = ModelIdentityService()
        let testLocation: String = "mlx-community/consistent-test"

        // Create components with shared identity service
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: sharedIdentityService
        )

        let downloader: HuggingFaceDownloader = HuggingFaceDownloader(
            fileManager: fileManager,
            enableProductionFeatures: false,
            identityService: sharedIdentityService
        )

        // When - Generate UUIDs from different components
        let uuidFromIdentityService: UUID = await sharedIdentityService.generateModelId(for: testLocation)

        // Create a temporary download and finalize it to check UUID consistency
        let tempURL: URL = tempDir.appendingPathComponent("temp_model")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        try "test content".write(to: tempURL.appendingPathComponent("model.bin"), atomically: true, encoding: .utf8)

        let finalizedModelInfo: ModelInfo = try await fileManager.finalizeDownload(
            repositoryId: testLocation,
            name: testLocation,
            backend: SendableModel.Backend.mlx,
            from: tempURL,
            totalSize: 12
        )

        // Then - All UUIDs should be identical
        #expect(uuidFromIdentityService == finalizedModelInfo.id)

        // Verify the model can be found in listDownloadedModels
        let models: [ModelInfo] = try await fileManager.listDownloadedModels()
        let foundModel: ModelInfo? = models.first { $0.id == uuidFromIdentityService }
        #expect(foundModel != nil)
        #expect(foundModel?.id == uuidFromIdentityService)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Repository-based finalization creates consistent metadata")
    func testRepositoryBasedFinalization() async throws {
        // Given
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        let identityService: ModelIdentityService = ModelIdentityService()
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: identityService
        )

        let repositoryId: String = "mlx-community/finalization-test"
        let testContent: String = "test model content"

        // Create temporary download
        let tempURL: URL = tempDir.appendingPathComponent("temp_download")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        try testContent.write(to: tempURL.appendingPathComponent("model.bin"), atomically: true, encoding: .utf8)

        // When - Finalize download
        let modelInfo: ModelInfo = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: repositoryId,
            backend: SendableModel.Backend.mlx,
            from: tempURL,
            totalSize: Int64(testContent.count)
        )

        // Then - Model info should have correct metadata
        #expect(modelInfo.name == repositoryId)
        #expect(modelInfo.backend == SendableModel.Backend.mlx)
        #expect(modelInfo.totalSize == Int64(testContent.count))
        #expect(modelInfo.metadata["repositoryId"] as? String == repositoryId)
        #expect(modelInfo.metadata["source"] as? String == "huggingface")
        #expect(modelInfo.metadata["downloadType"] as? String == "repository-based")

        // UUID should be deterministic based on repository ID
        let expectedUUID: UUID = await identityService.generateModelId(for: repositoryId)
        #expect(modelInfo.id == expectedUUID)

        // Model should be findable by location  
        let modelExists: Bool = await fileManager.modelExists(repositoryId: repositoryId)
        #expect(modelExists)

        // Files should exist in final location
        let finalLocation: URL = fileManager.modelDirectory(for: repositoryId, backend: SendableModel.Backend.mlx)
        let modelFileURL: URL = finalLocation.appendingPathComponent("model.bin")
        let modelFileExists: Bool = FileManager.default.fileExists(atPath: modelFileURL.path)
        #expect(modelFileExists)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Model with existing files but missing metadata is recovered")
    func testModelRecoveryWithMissingMetadata() async throws {
        // Given - Simulate a model that was downloaded but missing model_info.json
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        let identityService: ModelIdentityService = ModelIdentityService()
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: identityService
        )

        let repositoryId: String = "mlx-community/recovery-test"
        let repositoryDirName: String = repositoryId.replacingOccurrences(of: "/", with: "_")

        // Create model directory with files but no model_info.json
        let mlxDir: URL = modelsDir.appendingPathComponent("mlx")
        let modelDir: URL = mlxDir.appendingPathComponent(repositoryDirName)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let modelFile: URL = modelDir.appendingPathComponent("model.bin")
        try "model content".write(to: modelFile, atomically: true, encoding: .utf8)

        let configFile: URL = modelDir.appendingPathComponent("config.json")
        try "config content".write(to: configFile, atomically: true, encoding: .utf8)

        // When - List downloaded models (should recover the model)
        let models: [ModelInfo] = try await fileManager.listDownloadedModels()

        // Then - Model should be recovered with synthetic metadata
        let recoveredModel: ModelInfo? = models.first { $0.name.contains("recovery-test") }
        #expect(recoveredModel != nil)

        // UUID should be consistent with identity service
        let expectedUUID: UUID = await identityService.generateModelId(for: repositoryId)
        #expect(recoveredModel?.id == expectedUUID)
        #expect(recoveredModel?.backend == SendableModel.Backend.mlx)
        #expect(recoveredModel?.totalSize ?? 0 > 0) // Should have calculated directory size

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("End-to-end download creates findable model")
    func testEndToEndDownloadFlow() async throws {
        // Given
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Ensure clean state
        try? FileManager.default.removeItem(at: tempDir)

        // Create shared identity service
        let identityService: ModelIdentityService = ModelIdentityService()
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: identityService
        )

        let testLocation: String = "mlx-community/end-to-end-test"
        let testModel: SendableModel = SendableModel(
            id: await identityService.generateModelId(for: testLocation),
            ramNeeded: 1_000,
            modelType: .language,
            location: testLocation,
            architecture: .llama,
            backend: SendableModel.Backend.mlx
        )

        // Create mock downloader that simulates successful download
        let mockDownloader: TestMockStreamingDownloader = TestMockStreamingDownloader()
        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: DownloadTaskManager(),
            identityService: identityService,
            downloader: mockDownloader,
            fileManager: fileManager
        )

        // When - Perform complete download flow
        try await coordinator.start(model: testModel)

        // Wait for completion
        var state: DownloadStatus = await coordinator.state(for: testModel.location)
        var attempts: Int = 0
        while !state.isCompleted, attempts < 10 {
            try await Task.sleep(nanoseconds: 100_000_000)
            state = await coordinator.state(for: testModel.location)
            attempts += 1
        }

        // Then - Model should be completed and findable
        #expect(state.isCompleted)

        // Model should exist in file manager
        let modelExists: Bool = await fileManager.modelExists(repositoryId: testLocation)
        #expect(modelExists)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Mock Components for Testing

actor TestMockStreamingDownloader: StreamingDownloaderProtocol {
    func download(
        from url: URL,
        to destination: URL,
        headers _: [String: String],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Create directory structure like real HuggingFaceDownloader
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        // Simulate download by creating multiple test files like a real model
        let modelContent: String = "Mock model content for \(url.lastPathComponent)"
        let configContent: String = """
        {
          "model_type": "test",
          "vocab_size": 1000
        }
        """
        try modelContent.write(
            to: destination.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )
        try configContent.write(
            to: destination.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        // Simulate progress
        progressHandler(0.5)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        progressHandler(1.0)

        return destination
    }

    func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        try await download(from: url, to: destination, headers: headers, progressHandler: progressHandler)
    }

    func cancel(url _: URL) {
        // Mock implementation
    }

    func cancelAll() {
        // Mock implementation
    }

    func pause(url _: URL) {
        // Mock implementation
    }

    func pauseAll() {
        // Mock implementation
    }

    func resume(url _: URL) {
        // Mock implementation
    }

    func resumeAll() {
        // Mock implementation
    }
}
