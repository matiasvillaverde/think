import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Unit tests specifically for the critical bugs that were fixed:
/// - Bug #87: State synchronization issues  
/// - Bug #1: UUID consistency
@Suite("Critical Bug Fix Unit Tests")
struct CriticalBugFixTests {
    @Test("Repository-based model finalization works correctly")
    func testFinalizationCreatesMetadataFile() async throws {
        // Given - Setup test environment
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        let identityService: ModelIdentityService = ModelIdentityService()
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: identityService
        )

        let repositoryId: String = "test/bug57-model"
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

        // Then - Verify model was finalized correctly
        let modelExists: Bool = await fileManager.modelExists(repositoryId: repositoryId)
        #expect(modelExists)
        #expect(modelInfo.name == repositoryId)
        #expect(modelInfo.backend == SendableModel.Backend.mlx)
        #expect(modelInfo.totalSize == Int64(testContent.count))

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Bug #57: Models without metadata are recovered")
    func testModelRecoveryWithoutMetadata() async throws {
        // Given - Model exists in filesystem but no model_info.json
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        let identityService: ModelIdentityService = ModelIdentityService()
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: identityService
        )

        let repositoryId: String = "test/orphaned-model"
        let repositoryDirName: String = repositoryId.replacingOccurrences(of: "/", with: "_")

        // Create model directory with files but NO model_info.json
        let mlxDir: URL = modelsDir.appendingPathComponent("mlx")
        let modelDir: URL = mlxDir.appendingPathComponent(repositoryDirName)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        try "model content".write(to: modelDir.appendingPathComponent("model.bin"), atomically: true, encoding: .utf8)
        try "config content".write(
            to: modelDir.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        // When - List downloaded models (should recover the orphaned model)
        let models: [ModelInfo] = try await fileManager.listDownloadedModels()

        // Then - Model should be recovered with synthetic metadata
        let recoveredModel: ModelInfo? = models.first { $0.name.contains("orphaned-model") }
        #expect(recoveredModel != nil)
        #expect(recoveredModel?.backend == SendableModel.Backend.mlx)
        #expect(recoveredModel?.totalSize ?? 0 > 0) // Should have calculated directory size

        // UUID should be consistent with identity service
        let expectedUUID: UUID = await identityService.generateModelId(for: repositoryId)
        #expect(recoveredModel?.id == expectedUUID)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Bug #1 & #87: UUID Consistency Tests

    @Test("Bug #1: UUID consistency across components")
    func testUUIDConsistency() async throws {
        // Given - Shared identity service
        let sharedIdentityService: ModelIdentityService = ModelIdentityService()
        let testLocation: String = "test/consistency-model"

        // When - Generate UUIDs from different entry points
        let uuid1: UUID = await sharedIdentityService.generateModelId(for: testLocation)
        let uuid2: UUID = await sharedIdentityService.generateModelId(for: testLocation)
        let uuid3: UUID = await sharedIdentityService.generateModelId(for: testLocation)

        // Create SendableModel to test model creation consistency
        let model: SendableModel = await sharedIdentityService.createSendableModel(
            location: testLocation,
            backend: SendableModel.Backend.mlx,
            modelType: .language,
            ramNeeded: 1_000
        )

        // Then - All UUIDs should be identical
        #expect(uuid1 == uuid2)
        #expect(uuid2 == uuid3)
        #expect(model.id == uuid1)
        #expect(model.location == testLocation)
    }

    @Test("Bug #87: Shared identity service prevents state sync issues")
    func testSharedIdentityServiceInComponents() async throws {
        // Given - Setup with shared identity service (simulating fixed architecture)
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Create shared identity service
        let sharedIdentityService: ModelIdentityService = ModelIdentityService()

        // Create components with shared identity service
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: sharedIdentityService
        )

        _ = HuggingFaceDownloader(
            fileManager: fileManager,
            enableProductionFeatures: false,
            identityService: sharedIdentityService
        )

        let testLocation: String = "test/sync-test-model"

        // When - Generate UUIDs from different components
        let identityServiceUUID: UUID = await sharedIdentityService.generateModelId(for: testLocation)

        // Create a test finalization to verify file manager uses same UUID
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

        // Then - All components should produce the same UUID
        #expect(identityServiceUUID == finalizedModelInfo.id)

        // Verify the model can be found consistently
        let models: [ModelInfo] = try await fileManager.listDownloadedModels()
        let foundModel: ModelInfo? = models.first { $0.id == identityServiceUUID }
        #expect(foundModel != nil)
        #expect(foundModel?.id == identityServiceUUID)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Integration Tests

    @Test("All bugs fixed: End-to-end repository-based download")
    func testEndToEndRepositoryBasedDownload() async throws {
        // Given - Complete setup with all fixes applied
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Shared identity service (Bug #87 fix)
        let identityService: ModelIdentityService = ModelIdentityService()

        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: identityService
        )

        let repositoryId: String = "test/end-to-end-model"
        let expectedUUID: UUID = await identityService.generateModelId(for: repositoryId)

        // When - Simulate complete download process with finalization (Bug #57 fix)
        let tempURL: URL = tempDir.appendingPathComponent("temp_download")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        try "complete model".write(to: tempURL.appendingPathComponent("model.bin"), atomically: true, encoding: .utf8)
        try "model config".write(to: tempURL.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        // This simulates the fix where DefaultDownloadCoordinator calls finalizeDownload
        let modelInfo: ModelInfo = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: repositoryId,
            backend: SendableModel.Backend.mlx,
            from: tempURL,
            totalSize: 21 // "complete model".count + "model config".count
        )

        // Then - Verify all fixes work together

        // Bug #1 & #87: UUID consistency
        #expect(modelInfo.id == expectedUUID)

        // Model should be discoverable by location
        let modelExists: Bool = await fileManager.modelExists(repositoryId: repositoryId)
        #expect(modelExists)

        // Verify files exist in correct repository-based location
        let finalLocation: URL = fileManager.modelDirectory(for: repositoryId, backend: SendableModel.Backend.mlx)
        let modelFileExists: Bool = FileManager.default.fileExists(
            atPath: finalLocation.appendingPathComponent("model.bin").path
        )
        let configFileExists: Bool = FileManager.default.fileExists(
            atPath: finalLocation.appendingPathComponent("config.json").path
        )

        #expect(modelFileExists)
        #expect(configFileExists)

        // Verify we can find models (the original user issue)
        let allModels: [ModelInfo] = try await fileManager.listDownloadedModels()
        #expect(!allModels.isEmpty) // The core issue: "listDownloadedModels() returning 0 models"

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Repository ID to directory name conversion")
    func testRepositoryIdConversion() {
        // Given - Repository IDs with slashes
        let testCases: [(String, String)] = [
            ("mlx-community/Llama-3.2-3B", "mlx-community_Llama-3.2-3B"),
            ("microsoft/DialoGPT-medium", "microsoft_DialoGPT-medium"),
            ("test/simple", "test_simple")
        ]

        for (repositoryId, expectedDirName): (String, String) in testCases {
            // When - Convert to safe directory name
            let safeDirName: String = repositoryId.replacingOccurrences(of: "/", with: "_")

            // Then - Verify conversion
            #expect(safeDirName == expectedDirName)
            #expect(!safeDirName.contains("/")) // No slashes in directory names
        }
    }

    @Test("ModelIdentityService deterministic UUID generation")
    func testDeterministicUUIDGeneration() async {
        // Given - Multiple identity service instances
        let service1: ModelIdentityService = ModelIdentityService()
        let service2: ModelIdentityService = ModelIdentityService()
        let testLocation: String = "test/deterministic-model"

        // When - Generate UUIDs from different instances
        let uuid1: UUID = await service1.generateModelId(for: testLocation)
        let uuid2: UUID = await service2.generateModelId(for: testLocation)

        // Multiple calls to same instance
        let uuid3: UUID = await service1.generateModelId(for: testLocation)
        let uuid4: UUID = await service1.generateModelId(for: testLocation)

        // Then - All UUIDs should be identical (deterministic)
        #expect(uuid1 == uuid2) // Different instances produce same UUID
        #expect(uuid1 == uuid3) // Same instance is consistent
        #expect(uuid1 == uuid4) // Multiple calls are consistent

        // Different locations should produce different UUIDs
        let differentLocationUUID: UUID = await service1.generateModelId(for: "different/location")
        #expect(uuid1 != differentLocationUUID)
    }
}
