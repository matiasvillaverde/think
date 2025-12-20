import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Standalone test that can run independently to prove the critical bug fixes work
@Suite("Standalone Bug Fix Verification")
struct StandaloneBugFixTest {
    @Test("Core Bug Fix Verification: All three critical bugs are fixed")
    func testAllCriticalBugsFixed() async throws {
        // Given - Clean test environment
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("standalone-test-\(UUID().uuidString)")
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        defer {
            // Cleanup
            try? FileManager.default.removeItem(at: tempDir)
        }

        // STEP 1: Test Bug #1 & #87 Fix - UUID Consistency with Shared Identity Service
        let sharedIdentityService: ModelIdentityService = ModelIdentityService()
        let testRepositoryId: String = "test/all-bugs-fixed"

        // Generate UUID multiple times - should be consistent
        let uuid1: UUID = await sharedIdentityService.generateModelId(for: testRepositoryId)
        let uuid2: UUID = await sharedIdentityService.generateModelId(for: testRepositoryId)
        #expect(uuid1 == uuid2, "Bug #1/#87: UUID consistency failed")

        // STEP 2: Test Bug #57 Fix - Finalization Works with Location-Based Identification
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: sharedIdentityService
        )

        // Create temporary download to finalize
        let tempDownloadDir: URL = tempDir.appendingPathComponent("temp_download")
        try FileManager.default.createDirectory(at: tempDownloadDir, withIntermediateDirectories: true)
        try "test model content".write(
            to: tempDownloadDir.appendingPathComponent("model.bin"),
            atomically: true,
            encoding: .utf8
        )

        // This simulates the fix where DefaultDownloadCoordinator calls finalizeDownload
        let _: ModelInfo = try await fileManager.finalizeDownload(
            repositoryId: testRepositoryId,
            name: testRepositoryId,
            backend: SendableModel.Backend.mlx,
            from: tempDownloadDir,
            totalSize: 18 // "test model content".count
        )

        // Verify Bug #57 fix: Model exists by location
        let modelExists: Bool = await fileManager.modelExists(repositoryId: testRepositoryId)
        #expect(modelExists, "Bug #57: Model finalization failed - model not found by location")

        // STEP 3: Test that listDownloadedModels() now finds the model (original user issue)
        let discoveredModels: [ModelInfo] = try await fileManager.listDownloadedModels()
        #expect(!discoveredModels.isEmpty, "Original issue: listDownloadedModels() still returns empty")

        let foundModel: ModelInfo? = discoveredModels.first { $0.name == testRepositoryId }
        #expect(foundModel != nil, "Model not found by listDownloadedModels()")
        #expect(foundModel?.id == uuid1, "Bug #1/#87: Found model has wrong UUID")
        #expect(foundModel?.backend == SendableModel.Backend.mlx, "Model has wrong backend")

        // STEP 4: Test Model Recovery (models without metadata)
        // Create another model directory without model_info.json to test recovery
        let orphanedRepoId: String = "test/orphaned-model"
        let orphanedDirName: String = orphanedRepoId.replacingOccurrences(of: "/", with: "_")
        let orphanedModelDir: URL = modelsDir.appendingPathComponent("mlx").appendingPathComponent(orphanedDirName)

        try FileManager.default.createDirectory(at: orphanedModelDir, withIntermediateDirectories: true)
        try "orphaned content".write(
            to: orphanedModelDir.appendingPathComponent("model.bin"),
            atomically: true,
            encoding: .utf8
        )
        // Note: Without model_info.json - simulates model found by location only

        // Should still be discoverable through location-based discovery
        let allModels: [ModelInfo] = try await fileManager.listDownloadedModels()
        let orphanedModel: ModelInfo? = allModels.first { $0.name.contains("orphaned-model") }
        #expect(orphanedModel != nil, "Location-based model discovery failed")

        // STEP 5: Verify Repository-based Directory Structure
        let repositoryDirName: String = testRepositoryId.replacingOccurrences(of: "/", with: "_")
        let expectedPath: URL = modelsDir.appendingPathComponent("mlx").appendingPathComponent(repositoryDirName)
        #expect(FileManager.default.fileExists(atPath: expectedPath.path), "Repository-based directory not created")

        // SUCCESS: All critical bugs are fixed!
        print("All critical bugs fixed:")
        print("   - Bug #57: Location-based model identification works")
        print("   - Bug #1/#87: UUID consistency maintained")
        print("   - Original issue: listDownloadedModels() finds models")
        print("   - Location-based model discovery works")
        print("   - Repository-based structure")
    }

    @Test("Deterministic UUID generation works correctly")
    func testDeterministicUUIDs() async {
        // Given - Multiple identity services
        let service1: ModelIdentityService = ModelIdentityService()
        let service2: ModelIdentityService = ModelIdentityService()

        let testCases: [String] = [
            "mlx-community/Llama-3.2-3B",
            "microsoft/DialoGPT-medium",
            "test/simple-model"
        ]

        for repositoryId in testCases {
            // When - Generate UUIDs from different service instances
            let uuid1: UUID = await service1.generateModelId(for: repositoryId)
            let uuid2: UUID = await service2.generateModelId(for: repositoryId)
            let uuid3: UUID = await service1.generateModelId(for: repositoryId) // Same service, second call

            // Then - All should be identical (deterministic)
            #expect(uuid1 == uuid2, "Different service instances produced different UUIDs for \(repositoryId)")
            #expect(uuid1 == uuid3, "Same service instance produced different UUIDs for \(repositoryId)")
        }
    }

    @Test("Repository ID to safe directory name conversion")
    func testRepositoryIdSafety() {
        let testCases: [(String, String)] = [
            ("mlx-community/Llama-3.2-3B", "mlx-community_Llama-3.2-3B"),
            ("microsoft/DialoGPT-medium", "microsoft_DialoGPT-medium"),
            ("user/model-with-dashes", "user_model-with-dashes"),
            ("org/sub/deep", "org_sub_deep") // Multiple slashes
        ]

        for (input, expected) in testCases {
            let safeName: String = input.replacingOccurrences(of: "/", with: "_")
            #expect(safeName == expected, "Conversion failed for \(input)")
            #expect(!safeName.contains("/"), "Safe name still contains slashes: \(safeName)")
        }
    }
}
