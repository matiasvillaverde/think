import Foundation
@testable import ModelDownloader
import Testing
import ZIPFoundation

@Suite("CoreML Restructuring V2 Tests - Simplified Implementation")
struct CoreMLRestructuringV2Tests {
    @Test("Test exact HuggingFace ZIP structure with merges.txt")
    func testHuggingFaceStructureWithMerges() async throws {
        // Create structure: coreml-stable-diffusion/split-einsum/split-einsum/*
        let tempDir: URL = createTempDirectory()
        defer { cleanup(tempDir) }

        let deepPath: URL = tempDir
            .appendingPathComponent("coreml-stable-diffusion")
            .appendingPathComponent("split-einsum")
            .appendingPathComponent("split-einsum")

        try FileManager.default.createDirectory(at: deepPath, withIntermediateDirectories: true)

        // Add all expected files
        let files: [String: String] = [
            "merges.txt": "BPE merges content",
            "vocab.json": "{\"vocab\": true}",
            "config.json": "{\"config\": true}",
            "model_index.json": "{\"model_index\": true}",
            "tokenizer.json": "{\"tokenizer\": true}",
            "special_tokens_map.json": "{\"special_tokens\": true}"
        ]

        for (file, content) in files {
            try content.write(to: deepPath.appendingPathComponent(file), atomically: true, encoding: .utf8)
        }

        // Add model directories
        let unetDir: URL = deepPath.appendingPathComponent("Unet.mlmodelc")
        try FileManager.default.createDirectory(at: unetDir, withIntermediateDirectories: true)
        try "model data".write(to: unetDir.appendingPathComponent("model.mil"), atomically: true, encoding: .utf8)

        let textEncoderDir: URL = deepPath.appendingPathComponent("TextEncoder.mlmodelc")
        try FileManager.default.createDirectory(at: textEncoderDir, withIntermediateDirectories: true)
        try "encoder data".write(
            to: textEncoderDir.appendingPathComponent("model.mil"),
            atomically: true,
            encoding: .utf8
        )

        // Log initial structure
        print("\n📁 Initial directory structure:")
        printDirectoryTree(at: tempDir)

        // Run restructuring
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Log final structure
        print("\n📁 Final directory structure:")
        printDirectoryTree(at: tempDir)

        // Verify all files are at root
        for filename in files.keys {
            let rootPath: URL = tempDir.appendingPathComponent(filename)
            #expect(
                FileManager.default.fileExists(atPath: rootPath.path),
                "File '\(filename)' should be at root level"
            )

            // Verify content is preserved
            let content: String = try String(contentsOf: rootPath, encoding: .utf8)
            #expect(content == files[filename])
        }

        // Verify model directories are at root
        let rootUnet: URL = tempDir.appendingPathComponent("Unet.mlmodelc")
        let rootTextEncoder: URL = tempDir.appendingPathComponent("TextEncoder.mlmodelc")
        #expect(FileManager.default.fileExists(atPath: rootUnet.path))
        #expect(FileManager.default.fileExists(atPath: rootTextEncoder.path))

        // Verify model files inside are preserved
        let unetModel: URL = rootUnet.appendingPathComponent("model.mil")
        #expect(FileManager.default.fileExists(atPath: unetModel.path))
        #expect(try String(contentsOf: unetModel, encoding: .utf8) == "model data")

        // Verify nested directories are gone
        #expect(!FileManager.default.fileExists(atPath: deepPath.path))
    }

    @Test("Test already flat structure - should do nothing")
    func testAlreadyFlatStructure() async throws {
        let tempDir: URL = createTempDirectory()
        defer { cleanup(tempDir) }

        // Create files at root (already flat)
        try "merges content".write(
            to: tempDir.appendingPathComponent("merges.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "{\"config\": true}".write(
            to: tempDir.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        let mlmodelcDir: URL = tempDir.appendingPathComponent("Model.mlmodelc")
        try FileManager.default.createDirectory(at: mlmodelcDir, withIntermediateDirectories: true)
        try "model".write(to: mlmodelcDir.appendingPathComponent("model.mil"), atomically: true, encoding: .utf8)

        // Run restructuring
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Verify files still at root
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("merges.txt").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("config.json").path))
        #expect(FileManager.default.fileExists(atPath: mlmodelcDir.path))
    }

    @Test("Test no merges.txt found - should handle gracefully")
    func testNoMergesFile() async throws {
        let tempDir: URL = createTempDirectory()
        defer { cleanup(tempDir) }

        // Create structure without merges.txt
        let subDir: URL = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "{\"config\": true}".write(
            to: subDir.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "{\"vocab\": true}".write(
            to: subDir.appendingPathComponent("vocab.json"),
            atomically: true,
            encoding: .utf8
        )

        // Run restructuring - should handle gracefully
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Files should remain where they are since no merges.txt was found
        #expect(FileManager.default.fileExists(atPath: subDir.appendingPathComponent("config.json").path))
        #expect(FileManager.default.fileExists(atPath: subDir.appendingPathComponent("vocab.json").path))
    }

    @Test("Test deeply nested structure")
    func testDeeplyNestedStructure() async throws {
        let tempDir: URL = createTempDirectory()
        defer { cleanup(tempDir) }

        // Create very deep nesting
        let deepPath: URL = tempDir
            .appendingPathComponent("level1")
            .appendingPathComponent("level2")
            .appendingPathComponent("level3")
            .appendingPathComponent("level4")
            .appendingPathComponent("model")

        try FileManager.default.createDirectory(at: deepPath, withIntermediateDirectories: true)

        // Add model files at the deepest level
        try "merges".write(
            to: deepPath.appendingPathComponent("merges.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "{}".write(to: deepPath.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        // Run restructuring
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Verify files moved to root
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("merges.txt").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("config.json").path))

        // Verify deep structure is gone
        #expect(!FileManager.default.fileExists(atPath: deepPath.path))
    }

    @Test("Test filename conflicts")
    func testFilenameConflicts() async throws {
        let tempDir: URL = createTempDirectory()
        defer { cleanup(tempDir) }

        // Create existing file at root
        try "existing config".write(
            to: tempDir.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        // Create nested structure with conflicting file
        let nestedPath: URL = tempDir.appendingPathComponent("nested").appendingPathComponent("model")
        try FileManager.default.createDirectory(at: nestedPath, withIntermediateDirectories: true)
        try "merges".write(
            to: nestedPath.appendingPathComponent("merges.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "nested config".write(
            to: nestedPath.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        // Run restructuring
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Verify original file is preserved
        let originalConfig: String = try String(
            contentsOf: tempDir.appendingPathComponent("config.json"),
            encoding: .utf8
        )
        #expect(originalConfig == "existing config")

        // Verify nested file was renamed
        let renamedConfig: URL = tempDir.appendingPathComponent("config_1.json")
        #expect(FileManager.default.fileExists(atPath: renamedConfig.path))
        #expect(try String(contentsOf: renamedConfig, encoding: .utf8) == "nested config")

        // Verify merges.txt moved successfully
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("merges.txt").path))
    }

    @Test("Integration test with actual ZIP extraction workflow")
    func testFullZIPWorkflow() async throws {
        let tempDir: URL = createTempDirectory()
        defer { cleanup(tempDir) }

        // Step 1: Create a ZIP file with nested CoreML structure
        let zipContent: URL = tempDir.appendingPathComponent("zip-content")
        let modelDir: URL = zipContent
            .appendingPathComponent("coreml-stable-diffusion-2-1-base")
            .appendingPathComponent("split-einsum")
            .appendingPathComponent("split-einsum")

        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        // Add model files
        try "# Merges file\nĠThe 250".write(
            to: modelDir.appendingPathComponent("merges.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "{\"model_type\": \"stable-diffusion\"}".write(
            to: modelDir.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "{\"vocab_size\": 49408}".write(
            to: modelDir.appendingPathComponent("vocab.json"),
            atomically: true,
            encoding: .utf8
        )

        // Add model directories
        let unetDir: URL = modelDir.appendingPathComponent("Unet.mlmodelc")
        try FileManager.default.createDirectory(at: unetDir, withIntermediateDirectories: true)
        try Data("CoreML model data".utf8).write(to: unetDir.appendingPathComponent("model.mil"))

        // Create ZIP
        let zipPath: URL = tempDir.appendingPathComponent("model.zip")
        try FileManager.default.zipItem(at: zipContent, to: zipPath)
        try FileManager.default.removeItem(at: zipContent)

        // Step 2: Extract ZIP (simulating download completion)
        let extractDir: URL = tempDir.appendingPathComponent("extracted")
        let extractor: ZipExtractor = ZipExtractor()
        _ = try await extractor.extractZip(at: zipPath, to: extractDir)

        print("\n📁 After extraction:")
        printDirectoryTree(at: extractDir)

        // Step 3: Restructure for CoreML
        try await extractor.restructureCoreMLFiles(at: extractDir)

        print("\n📁 After restructuring:")
        printDirectoryTree(at: extractDir)

        // Verify final structure is flat
        let mergesPath: URL = extractDir.appendingPathComponent("merges.txt")
        let configPath: URL = extractDir.appendingPathComponent("config.json")
        let vocabPath: URL = extractDir.appendingPathComponent("vocab.json")
        let unetPath: URL = extractDir.appendingPathComponent("Unet.mlmodelc")

        #expect(FileManager.default.fileExists(atPath: mergesPath.path))
        #expect(FileManager.default.fileExists(atPath: configPath.path))
        #expect(FileManager.default.fileExists(atPath: vocabPath.path))
        #expect(FileManager.default.fileExists(atPath: unetPath.path))

        // Verify content is correct
        let mergesContent: String = try String(contentsOf: mergesPath, encoding: .utf8)
        #expect(mergesContent.contains("Merges file"))

        // Verify no nested directories remain
        let contents: [URL] = try FileManager.default.contentsOfDirectory(
            at: extractDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        // Should only have model files and .mlmodelc directories at root
        for item: URL in contents {
            let isDirectory: Bool = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                // Only .mlmodelc directories should exist
                #expect(item.lastPathComponent.hasSuffix(".mlmodelc"))
            }
        }

        print("\n✅ Full CoreML workflow test passed!")
    }

    // MARK: - Helper Functions

    private func createTempDirectory() -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreMLRestructuringV2Tests-\(UUID())")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanup(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    private func printDirectoryTree(at url: URL, indent: Int = 0) {
        let prefix: String = String(repeating: "  ", count: indent)

        do {
            let contents: [URL] = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item: URL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let isDirectory: Bool = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let icon: String = isDirectory ? "📁" : "📄"
                print("\(prefix)\(icon) \(item.lastPathComponent)")

                if isDirectory {
                    printDirectoryTree(at: item, indent: indent + 1)
                }
            }
        } catch {
            print("\(prefix)❌ Error reading directory: \(error)")
        }
    }
}
