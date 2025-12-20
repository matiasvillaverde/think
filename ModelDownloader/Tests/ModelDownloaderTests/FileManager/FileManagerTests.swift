import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelFileManager Tests")
internal struct FileManagerTests {
    @Test("Model directory path generation")
    func testModelDirectoryPath() {
        let repositoryId: String = "test/model"
        let backend: SendableModel.Backend = SendableModel.Backend.mlx
        let baseURL: URL = URL(fileURLWithPath: "/test/models")
        let manager: ModelFileManager = ModelFileManager(modelsDirectory: baseURL)

        let result: URL = manager.modelDirectory(for: repositoryId, backend: backend)
        let expected: URL = baseURL
            .appendingPathComponent("mlx", isDirectory: true)
            .appendingPathComponent(repositoryId.replacingOccurrences(of: "/", with: "_"), isDirectory: true)

        #expect(result == expected)
    }

    @Test("Temporary directory path generation")
    func testTemporaryDirectoryPath() {
        let repositoryId: String = "test/model"
        let baseURL: URL = URL(fileURLWithPath: "/test/temp")
        let manager: ModelFileManager = ModelFileManager(temporaryDirectory: baseURL)

        let result: URL = manager.temporaryDirectory(for: repositoryId)
        let expected: URL = baseURL.appendingPathComponent(
            repositoryId.replacingOccurrences(of: "/", with: "_"),
            isDirectory: true
        )

        #expect(result == expected)
    }

    @Test("Mock file manager operations")
    func testMockFileManagerOperations() async throws {
        let mockManager: MockFileManager = MockFileManager()
        let repositoryId: String = "test/model"
        let backend: SendableModel.Backend = SendableModel.Backend.gguf

        // Initially no models
        let initialModels: [ModelInfo] = try await mockManager.listDownloadedModels()
        #expect(initialModels.isEmpty)

        // Model doesn't exist initially
        let exists: Bool = await mockManager.modelExists(repositoryId: repositoryId)
        #expect(!exists)

        // Add a model
        let modelInfo: ModelInfo = ModelInfo(
            id: UUID(),
            name: repositoryId,
            backend: backend,
            location: mockManager.modelDirectory(for: repositoryId, backend: backend),
            totalSize: 1_024,
            downloadDate: Date()
        )

        mockManager.addModel(modelInfo, repositoryId: repositoryId)

        // Now model exists
        let existsAfter: Bool = await mockManager.modelExists(repositoryId: repositoryId)
        #expect(existsAfter)

        // Can list models
        let modelsAfter: [ModelInfo] = try await mockManager.listDownloadedModels()
        let expectedModelCount: Int = 1
        #expect(modelsAfter.count == expectedModelCount)
        #expect(modelsAfter.first?.name == repositoryId)

        // Can get model size
        let size: Int64? = await mockManager.getModelSize(repositoryId: repositoryId)
        let expectedSize: Int64 = 1_024
        #expect(size == expectedSize)

        // Can delete model
        try await mockManager.deleteModel(repositoryId: repositoryId)
        let existsAfterDelete: Bool = await mockManager.modelExists(repositoryId: repositoryId)
        #expect(!existsAfterDelete)
    }

    @Test("Disk space validation")
    func testDiskSpaceValidation() async {
        let mockManager: MockFileManager = MockFileManager()

        // Set available space to 1MB
        mockManager.setAvailableSpace(1_000_000)

        // Check space for 500KB (should pass with 20% buffer)
        let hasSpace500KB: Bool = await mockManager.hasEnoughSpace(for: 500_000)
        #expect(hasSpace500KB)

        // Check space for 900KB (should fail due to 20% buffer requiring 1.08MB)
        let hasSpace900KB: Bool = await mockManager.hasEnoughSpace(for: 900_000)
        #expect(!hasSpace900KB)

        // Check available space
        let available: Int64? = await mockManager.availableDiskSpace()
        let expectedAvailable: Int64 = 1_000_000
        #expect(available == expectedAvailable)
    }

    @Test("Model finalization")
    func testModelFinalization() async throws {
        let mockManager: MockFileManager = MockFileManager()
        let repositoryId: String = "test/model"
        let tempURL: URL = URL(fileURLWithPath: "/temp/download")

        let result: ModelInfo = try await mockManager.finalizeDownload(
            repositoryId: repositoryId,
            name: "Test Model",
            backend: SendableModel.Backend.coreml,
            from: tempURL,
            totalSize: 1_024
        )

        #expect(result.name == "Test Model")
        #expect(result.backend == SendableModel.Backend.coreml)
        let expectedTotalSize: Int64 = 1_024
        #expect(result.totalSize == expectedTotalSize) // Mock size

        // Verify model was added
        let exists: Bool = await mockManager.modelExists(repositoryId: repositoryId)
        #expect(exists)
    }

    @Test("Multiple format support")
    func testMultipleFormatSupport() async throws {
        let mockManager: MockFileManager = MockFileManager()

        // Add models with different formats
        for (index, backend): (Int, SendableModel.Backend) in SendableModel.Backend.allCases.enumerated() {
            let repositoryId: String = "test/model\(index)"
            let modelInfo: ModelInfo = ModelInfo(
                id: UUID(), // Different ID for each format
                name: "Test \(backend.rawValue) Model",
                backend: backend,
                location: mockManager.modelDirectory(for: repositoryId, backend: backend),
                totalSize: 1_024,
                downloadDate: Date()
            )
            mockManager.addModel(modelInfo, repositoryId: repositoryId)
        }

        let models: [ModelInfo] = try await mockManager.listDownloadedModels()
        let expectedBackendCount: Int = SendableModel.Backend.allCases.count
        #expect(models.count == expectedBackendCount)

        let backends: Set<SendableModel.Backend> = Set(models.map(\.backend))
        #expect(backends == Set(SendableModel.Backend.allCases))
    }
}

@Suite("ModelPath Tests")
internal struct ModelPathTests {
    @Test("Default paths")
    func testDefaultPaths() {
        let modelsDir: URL = ModelPath.defaultModelsDirectory
        let tempDir: URL = ModelPath.defaultTemporaryDirectory

        #expect(modelsDir.lastPathComponent == "Models")
        #expect(tempDir.lastPathComponent == "Downloads")
        #expect(modelsDir.path.contains("ThinkAI"))
        #expect(tempDir.path.contains("ThinkAI"))
    }

    @Test("Path validation")
    func testPathValidation() {
        let baseDir: URL = URL(fileURLWithPath: "/safe/models")
        let modelPath: ModelPath = ModelPath(baseDirectory: baseDir)

        let validPath: URL = baseDir.appendingPathComponent("test")
        let invalidPath: URL = URL(fileURLWithPath: "/dangerous/path")

        #expect(modelPath.isValidModelPath(validPath))
        #expect(!modelPath.isValidModelPath(invalidPath))
    }

    @Test("UUID extraction")
    func testUUIDExtraction() {
        let modelPath: ModelPath = ModelPath(baseDirectory: URL(fileURLWithPath: "/test"))
        let uuid: UUID = UUID()
        let pathWithUUID: URL = URL(fileURLWithPath: "/test/models/mlx/\(uuid.uuidString)/file.txt")

        let extracted: UUID? = modelPath.extractModelId(from: pathWithUUID)
        #expect(extracted == uuid)

        // Test path without UUID
        let pathWithoutUUID: URL = URL(fileURLWithPath: "/test/models/some-model/file.txt")
        let extractedNil: UUID? = modelPath.extractModelId(from: pathWithoutUUID)
        #expect(extractedNil == nil)
    }

    @Test("Format directories")
    func testFormatDirectories() {
        let baseDir: URL = URL(fileURLWithPath: "/test/models")
        let modelPath: ModelPath = ModelPath(baseDirectory: baseDir)

        for backend: SendableModel.Backend in SendableModel.Backend.allCases {
            let backendDir: URL = modelPath.backendDirectory(for: backend)
            let expected: URL = baseDir.appendingPathComponent(
                backend.rawValue,
                isDirectory: true
            )
            #expect(backendDir == expected)
        }
    }
}
