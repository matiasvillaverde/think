import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("CoreML Model Flattening Tests")
struct CoreMLFlatteningTests {
    @Test("Flattens nested CoreML model structure during finalization")
    func testCoreMLModelFlattening() async throws {
        // Given
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Ensure clean state
        try? FileManager.default.removeItem(at: tempDir)

        // Create file manager
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )

        // Create nested CoreML structure in temp directory
        let repositoryId: String = "coreml-community/test-model"
        let tempModelDir: URL = tempDir.appendingPathComponent(repositoryId.safeDirectoryName)
        let nestedDir: URL = tempModelDir
            .appendingPathComponent("split-einsum")
            .appendingPathComponent("test-model_split-einsum")

        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)

        // Create CoreML model files in nested directory
        let mergesContent: String = "test merges content"
        let vocabContent: String = "{\"test\": \"vocab\"}"
        let configContent: String = "{\"model_type\": \"stable_diffusion\"}"

        try mergesContent.write(to: nestedDir.appendingPathComponent("merges.txt"), atomically: true, encoding: .utf8)
        try vocabContent.write(to: nestedDir.appendingPathComponent("vocab.json"), atomically: true, encoding: .utf8)
        try configContent.write(to: nestedDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        // Create a fake .mlmodelc directory
        let mlmodelcDir: URL = nestedDir.appendingPathComponent("TextEncoder.mlmodelc")
        try FileManager.default.createDirectory(at: mlmodelcDir, withIntermediateDirectories: true)
        try "model data".write(to: mlmodelcDir.appendingPathComponent("model.mil"), atomically: true, encoding: .utf8)

        // When - Finalize the download
        _ = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: "Test Model",
            backend: .coreml,
            from: tempModelDir,
            totalSize: 1_000
        )

        // Then - Model files should be at the root of the final location
        let finalModelDir: URL = fileManager.modelDirectory(for: repositoryId, backend: .coreml)

        // Check that files are at root level
        let mergesPath: String = finalModelDir.appendingPathComponent("merges.txt").path
        let vocabPath: String = finalModelDir.appendingPathComponent("vocab.json").path
        let configPath: String = finalModelDir.appendingPathComponent("config.json").path
        let mlmodelcPath: String = finalModelDir.appendingPathComponent("TextEncoder.mlmodelc").path

        let mergesExists: Bool = FileManager.default.fileExists(atPath: mergesPath)
        let vocabExists: Bool = FileManager.default.fileExists(atPath: vocabPath)
        let configExists: Bool = FileManager.default.fileExists(atPath: configPath)
        let mlmodelcExists: Bool = FileManager.default.fileExists(atPath: mlmodelcPath)

        #expect(mergesExists)
        #expect(vocabExists)
        #expect(configExists)
        #expect(mlmodelcExists)

        // Check that nested directories were removed
        let splitEinsumExists: Bool = FileManager.default.fileExists(
            atPath: finalModelDir.appendingPathComponent("split-einsum").path
        )
        #expect(!splitEinsumExists)

        // Verify file contents are preserved
        let mergesData: String = try String(
            contentsOf: finalModelDir.appendingPathComponent("merges.txt"),
            encoding: .utf8
        )
        #expect(mergesData == mergesContent)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: modelsDir)
    }

    @Test("Skips flattening when CoreML files are already at root")
    func testSkipsFlatteningWhenAlreadyFlat() async throws {
        // Given
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")
        defer {
            try? FileManager.default.removeItem(at: tempDir)
            try? FileManager.default.removeItem(at: modelsDir)
        }

        // Ensure clean state
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: modelsDir)

        // Create file manager
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )

        // Create flat CoreML structure in temp directory
        let repositoryId: String = "coreml-community/flat-model"

        // Clean the final directory to avoid conflicts from previous runs
        let finalDir: URL = fileManager.modelDirectory(for: repositoryId, backend: .coreml)
        try? FileManager.default.removeItem(at: finalDir)
        let tempModelDir: URL = tempDir.appendingPathComponent(repositoryId.safeDirectoryName)

        try FileManager.default.createDirectory(at: tempModelDir, withIntermediateDirectories: true)

        // Create CoreML model files at root
        try "merges".write(to: tempModelDir.appendingPathComponent("merges.txt"), atomically: true, encoding: .utf8)
        try "vocab".write(to: tempModelDir.appendingPathComponent("vocab.json"), atomically: true, encoding: .utf8)

        // Verify files exist before finalization
        let tempMergesPath: String = tempModelDir.appendingPathComponent("merges.txt").path
        let tempVocabPath: String = tempModelDir.appendingPathComponent("vocab.json").path
        let tempMergesExists: Bool = FileManager.default.fileExists(atPath: tempMergesPath)
        let tempVocabExists: Bool = FileManager.default.fileExists(atPath: tempVocabPath)
        #expect(tempMergesExists, "merges.txt should exist in temp dir")
        #expect(tempVocabExists, "vocab.json should exist in temp dir")

        // When - Finalize the download
        _ = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: "Flat Model",
            backend: .coreml,
            from: tempModelDir,
            totalSize: 500
        )

        // Then - Files should still be at root
        let finalModelDir: URL = fileManager.modelDirectory(for: repositoryId, backend: .coreml)

        // Then - Files should exist with original or disambiguated names
        let rootItems: [String] = try FileManager.default
            .contentsOfDirectory(at: finalModelDir, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
        let mergesExists: Bool = rootItems.contains("merges.txt") ||
            rootItems.contains { $0.hasPrefix("merges_") && $0.hasSuffix(".txt") }
        let vocabExists: Bool = rootItems.contains("vocab.json") ||
            rootItems.contains { $0.hasPrefix("vocab_") && $0.hasSuffix(".json") }

        #expect(mergesExists, "merges.txt should exist in final dir")
        #expect(vocabExists, "vocab.json should exist in final dir")
    }

    @Test("Handles naming conflicts during flattening")
    func testHandlesNamingConflicts() async throws {
        // Given
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Ensure clean state
        try? FileManager.default.removeItem(at: tempDir)

        // Create file manager
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )

        // Create structure with potential naming conflicts
        let repositoryId: String = "coreml-community/conflict-model"
        let tempModelDir: URL = tempDir.appendingPathComponent(repositoryId.safeDirectoryName)
        let subDir1: URL = tempModelDir.appendingPathComponent("variant1")
        let subDir2: URL = tempModelDir.appendingPathComponent("variant2")

        try FileManager.default.createDirectory(at: subDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subDir2, withIntermediateDirectories: true)

        // Create files with same names in different directories
        try "config1".write(to: subDir1.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "config2".write(to: subDir2.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        // When - Finalize the download
        _ = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: "Conflict Model",
            backend: .coreml,
            from: tempModelDir,
            totalSize: 300
        )

        // Then - Both files should exist with different names
        let finalModelDir: URL = fileManager.modelDirectory(for: repositoryId, backend: .coreml)

        let files: [URL] = try FileManager.default.contentsOfDirectory(
            at: finalModelDir,
            includingPropertiesForKeys: nil
        )
        let configFiles: [URL] = files.filter { $0.lastPathComponent.contains("config") }

        #expect(configFiles.count == 2)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: modelsDir)
    }

    @Test("Does not flatten non-CoreML models")
    func testDoesNotFlattenNonCoreMLModels() async throws {
        // Given
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Ensure clean state
        try? FileManager.default.removeItem(at: tempDir)

        // Create file manager
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )

        // Create nested MLX structure
        let repositoryId: String = "mlx-community/test-model"
        let tempModelDir: URL = tempDir.appendingPathComponent(repositoryId.safeDirectoryName)
        let nestedDir: URL = tempModelDir.appendingPathComponent("nested").appendingPathComponent("deep")

        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        try "model".write(to: nestedDir.appendingPathComponent("model.safetensors"), atomically: true, encoding: .utf8)

        // When - Finalize the download for MLX backend
        _ = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: "MLX Model",
            backend: .mlx,
            from: tempModelDir,
            totalSize: 1_000
        )

        // Then - Nested structure should be preserved
        let finalModelDir: URL = fileManager.modelDirectory(for: repositoryId, backend: .mlx)
        let nestedFileExists: Bool = FileManager.default.fileExists(
            atPath: finalModelDir
                .appendingPathComponent("nested")
                .appendingPathComponent("deep")
                .appendingPathComponent("model.safetensors").path
        )

        #expect(nestedFileExists)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: modelsDir)
    }
}
