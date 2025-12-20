import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("Deep Nested CoreML Tests")
struct DeepNestedCoreMLTests {
    @Test("Handles deeply nested CoreML structure like split-einsum")
    func testDeepNestedCoreMLStructure() async throws {
        // Given - simulate the exact structure from the logs
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Ensure clean state
        try? FileManager.default.removeItem(at: tempDir)

        // Create file manager
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )

        // Create the exact nested structure we see in the logs
        let repositoryId: String = "coreml-community/coreml-Inkpunk-Diffusion"
        let tempDownloadDir: URL = tempDir.appendingPathComponent("Downloads")
            .appendingPathComponent(repositoryId.replacingOccurrences(of: "/", with: "_"))

        // This simulates the nested path: split-einsum/Inkpunk-Diffusion-v2_split-einsum/
        let nestedModelDir: URL = tempDownloadDir
            .appendingPathComponent("split-einsum")
            .appendingPathComponent("Inkpunk-Diffusion-v2_split-einsum")

        try FileManager.default.createDirectory(at: nestedModelDir, withIntermediateDirectories: true)

        // Create CoreML model files in the deeply nested directory
        let testFiles: [(String, String)] = [
            ("merges.txt", "test merges content"),
            ("vocab.json", "{\"test\": \"vocab\"}"),
            ("config.json", "{\"model_type\": \"stable_diffusion\"}")
        ]

        for (filename, content) in testFiles {
            try content.write(
                to: nestedModelDir.appendingPathComponent(filename),
                atomically: true,
                encoding: .utf8
            )
        }

        // Create .mlmodelc directories
        let mlmodelcNames: [String] = ["TextEncoder.mlmodelc", "Unet.mlmodelc", "VAEDecoder.mlmodelc"]
        for mlmodelcName in mlmodelcNames {
            let mlmodelcDir: URL = nestedModelDir.appendingPathComponent(mlmodelcName)
            try FileManager.default.createDirectory(at: mlmodelcDir, withIntermediateDirectories: true)
            try "model data".write(
                to: mlmodelcDir.appendingPathComponent("model.mil"),
                atomically: true,
                encoding: .utf8
            )
        }

        // When - Finalize the download from the temp download directory
        _ = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: "Inkpunk Diffusion",
            backend: .coreml,
            from: tempDownloadDir, // Note: passing the top-level download dir
            totalSize: 2_000_000_000
        )

        // Then - Files should be at the root of the final model directory
        let finalModelDir: URL = fileManager.modelDirectory(for: repositoryId, backend: .coreml)

        // Check that essential files are at root
        let mergesPath: URL = finalModelDir.appendingPathComponent("merges.txt")
        let vocabPath: URL = finalModelDir.appendingPathComponent("vocab.json")
        let configPath: URL = finalModelDir.appendingPathComponent("config.json")

        #expect(FileManager.default.fileExists(atPath: mergesPath.path))
        #expect(FileManager.default.fileExists(atPath: vocabPath.path))
        #expect(FileManager.default.fileExists(atPath: configPath.path))

        // Check that .mlmodelc directories are at root
        for mlmodelcName in mlmodelcNames {
            let mlmodelcPath: URL = finalModelDir.appendingPathComponent(mlmodelcName)
            #expect(FileManager.default.fileExists(atPath: mlmodelcPath.path))
        }

        // Verify no nested directories remain
        let splitEinsumPath: URL = finalModelDir.appendingPathComponent("split-einsum")
        #expect(!FileManager.default.fileExists(atPath: splitEinsumPath.path))

        // Also verify the intermediate directory doesn't exist
        let intermediateDir: URL = finalModelDir
            .appendingPathComponent("split-einsum")
            .appendingPathComponent("Inkpunk-Diffusion-v2_split-einsum")
        #expect(!FileManager.default.fileExists(atPath: intermediateDir.path))

        // List all files at root to debug
        let rootContents: [URL] = try FileManager.default.contentsOfDirectory(
            at: finalModelDir,
            includingPropertiesForKeys: nil
        )
        print("Files at root: \(rootContents.map(\.lastPathComponent))")
        #expect(rootContents.count >= 6) // 3 text files + 3 mlmodelc directories

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: modelsDir)
    }
}
