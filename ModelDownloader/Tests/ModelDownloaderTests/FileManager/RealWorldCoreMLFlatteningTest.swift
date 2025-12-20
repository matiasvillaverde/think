import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("Real World CoreML Flattening Tests")
struct RealWorldCoreMLFlatteningTest {
    @Test("Simulates actual CoreML download and extraction flow")
    func testRealWorldCoreMLFlow() async throws {
        // Given - simulate the exact flow from the logs
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")

        // Create file manager
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )

        // Simulate the download structure
        let repositoryId: String = "coreml-community/coreml-Inkpunk-Diffusion"
        let downloadBaseDir: URL = tempDir.appendingPathComponent("Downloads")
            .appendingPathComponent(repositoryId.replacingOccurrences(of: "/", with: "_"))

        // Simulate extraction: the ZIP was extracted to split-einsum/Inkpunk-Diffusion-v2_split-einsum/
        let extractionDir: URL = downloadBaseDir
            .appendingPathComponent("split-einsum")
            .appendingPathComponent("Inkpunk-Diffusion-v2_split-einsum")

        // After extraction restructuring, files should be at extractionDir level
        // (The ZipExtractor's restructureCoreMLFiles would have moved files here)
        try FileManager.default.createDirectory(at: extractionDir, withIntermediateDirectories: true)

        // Create files at the extraction directory (after ZIP restructuring)
        let testFiles: [(String, String)] = [
            ("merges.txt", "test merges content"),
            ("vocab.json", "{\"test\": \"vocab\"}"),
            ("config.json", "{\"model_type\": \"stable_diffusion\"}")
        ]

        for (filename, content) in testFiles {
            try content.write(
                to: extractionDir.appendingPathComponent(filename),
                atomically: true,
                encoding: .utf8
            )
        }

        // Create .mlmodelc directories
        let mlmodelcNames: [String] = ["TextEncoder.mlmodelc", "Unet.mlmodelc", "VAEDecoder.mlmodelc"]
        for mlmodelcName in mlmodelcNames {
            let mlmodelcDir: URL = extractionDir.appendingPathComponent(mlmodelcName)
            try FileManager.default.createDirectory(at: mlmodelcDir, withIntermediateDirectories: true)
            try "model data".write(
                to: mlmodelcDir.appendingPathComponent("model.mil"),
                atomically: true,
                encoding: .utf8
            )
        }

        // Log the structure before finalization
        print("=== Structure before finalization ===")
        logDirectoryStructure(at: downloadBaseDir)

        // When - Finalize the download (this is what happens in the real flow)
        // The entire downloadBaseDir is passed to finalization
        _ = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: "Inkpunk Diffusion",
            backend: .coreml,
            from: downloadBaseDir,
            totalSize: 2_000_000_000
        )

        // Then - Files should be at the root of the final model directory
        let finalModelDir: URL = fileManager.modelDirectory(for: repositoryId, backend: .coreml)

        // Log the final structure
        print("\n=== Final structure ===")
        logDirectoryStructure(at: finalModelDir)

        // Check that essential files are at root
        let mergesPath: URL = finalModelDir.appendingPathComponent("merges.txt")
        let vocabPath: URL = finalModelDir.appendingPathComponent("vocab.json")
        let configPath: URL = finalModelDir.appendingPathComponent("config.json")

        print("\nChecking files at root:")
        print("merges.txt exists: \(FileManager.default.fileExists(atPath: mergesPath.path))")
        print("vocab.json exists: \(FileManager.default.fileExists(atPath: vocabPath.path))")
        print("config.json exists: \(FileManager.default.fileExists(atPath: configPath.path))")

        #expect(FileManager.default.fileExists(atPath: mergesPath.path), "merges.txt should be at root")
        #expect(FileManager.default.fileExists(atPath: vocabPath.path), "vocab.json should be at root")
        #expect(FileManager.default.fileExists(atPath: configPath.path), "config.json should be at root")

        // Check that .mlmodelc directories are at root
        for mlmodelcName in mlmodelcNames {
            let mlmodelcPath: URL = finalModelDir.appendingPathComponent(mlmodelcName)
            #expect(FileManager.default.fileExists(atPath: mlmodelcPath.path), "\(mlmodelcName) should be at root")
        }

        // Verify no nested directories remain
        let splitEinsumPath: URL = finalModelDir.appendingPathComponent("split-einsum")
        #expect(
            !FileManager.default.fileExists(atPath: splitEinsumPath.path),
            "split-einsum directory should not exist"
        )

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: modelsDir)
    }

    private func logDirectoryStructure(at url: URL, indent: String = "") {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("\(indent)\(url.lastPathComponent) [DOES NOT EXIST]")
            return
        }

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            print("\(indent)\(url.lastPathComponent)/")
            if let contents: [URL] = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            ) {
                for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    logDirectoryStructure(at: item, indent: indent + "  ")
                }
            }
        } else {
            print("\(indent)\(url.lastPathComponent)")
        }
    }
}
