import Foundation
@testable import ModelDownloader
import Testing
import ZIPFoundation

@Suite("CoreML Model Restructuring Tests")
struct CoreMLRestructuringTests {
    @Test("Restructure nested CoreML files to flat structure")
    func testRestructureCoreMLFiles() async throws {
        // Create temporary directory for test
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-coreml-restructure-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create nested directory structure like real CoreML models
        let splitEinsumDir: URL = tempDir.appendingPathComponent("split-einsum")
        let modelSubDir: URL = splitEinsumDir.appendingPathComponent("v1-5_split-einsum")

        try FileManager.default.createDirectory(
            at: modelSubDir,
            withIntermediateDirectories: true
        )

        // Create model files in nested directory
        let files: [String: String] = [
            "merges.txt": "Mock merges content",
            "vocab.json": "{\"vocab\": true}",
            "config.json": "{\"config\": true}",
            "model_index.json": "{\"model_index\": true}",
            "tokenizer.json": "{\"tokenizer\": true}"
        ]

        for (filename, content) in files {
            let filePath: URL = modelSubDir.appendingPathComponent(filename)
            try content.write(to: filePath, atomically: true, encoding: .utf8)
        }

        // Create a .mlmodelc directory structure
        let mlmodelcDir: URL = modelSubDir.appendingPathComponent("Unet.mlmodelc")
        try FileManager.default.createDirectory(at: mlmodelcDir, withIntermediateDirectories: true)
        try "model data".write(
            to: mlmodelcDir.appendingPathComponent("model.mil"),
            atomically: true,
            encoding: .utf8
        )

        // Also create files in the intermediate directory to test selective moving
        let originalDir: URL = tempDir.appendingPathComponent("original")
        try FileManager.default.createDirectory(at: originalDir, withIntermediateDirectories: true)
        try "should not move".write(
            to: originalDir.appendingPathComponent("other.txt"),
            atomically: true,
            encoding: .utf8
        )

        // Log initial structure
        print("\n📁 Initial directory structure:")
        printDirectoryTree(at: tempDir, indent: 0)

        // Run the restructuring
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Log final structure
        print("\n📁 Final directory structure:")
        printDirectoryTree(at: tempDir, indent: 0)

        // Verify all model files are now at root level
        for filename: String in files.keys {
            let rootPath: URL = tempDir.appendingPathComponent(filename)
            #expect(
                FileManager.default.fileExists(atPath: rootPath.path),
                "File '\(filename)' should exist at root level"
            )

            // Verify content is preserved
            let content: String = try String(contentsOf: rootPath, encoding: .utf8)
            #expect(content == files[filename])
        }

        // Verify .mlmodelc was moved to root
        let rootMLModelc: URL = tempDir.appendingPathComponent("Unet.mlmodelc")
        #expect(
            FileManager.default.fileExists(atPath: rootMLModelc.path),
            "Unet.mlmodelc should exist at root level"
        )

        // Verify the model.mil file inside mlmodelc is preserved
        let modelMilPath: URL = rootMLModelc.appendingPathComponent("model.mil")
        #expect(FileManager.default.fileExists(atPath: modelMilPath.path))
        let modelContent: String = try String(contentsOf: modelMilPath, encoding: .utf8)
        #expect(modelContent == "model data")

        // Verify original nested directories no longer exist
        #expect(
            !FileManager.default.fileExists(atPath: modelSubDir.path),
            "Original nested directory should be removed"
        )

        // Verify non-model files weren't moved
        let otherFile: URL = originalDir.appendingPathComponent("other.txt")
        #expect(
            FileManager.default.fileExists(atPath: otherFile.path),
            "Non-model files should remain in place"
        )

        print("\nCoreML restructuring test passed!")
    }

    @Test("Handle filename conflicts during restructuring")
    func testFilenameConflictHandling() async throws {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-conflict-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create existing file at root
        let existingConfig: URL = tempDir.appendingPathComponent("config.json")
        try "{\"existing\": true}".write(to: existingConfig, atomically: true, encoding: .utf8)

        // Create nested directory with conflicting file
        let nestedDir: URL = tempDir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        let nestedConfig: URL = nestedDir.appendingPathComponent("config.json")
        try "{\"nested\": true}".write(to: nestedConfig, atomically: true, encoding: .utf8)
        // Add merges.txt to indicate this is the CoreML content directory
        let mergesFile: URL = nestedDir.appendingPathComponent("merges.txt")
        try "test merges".write(to: mergesFile, atomically: true, encoding: .utf8)

        // Run restructuring
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Debug: Print directory structure
        print("\n📁 After restructuring:")
        printDirectoryTree(at: tempDir, indent: 0)

        // Verify original file is preserved
        let originalContent: String = try String(contentsOf: existingConfig, encoding: .utf8)
        #expect(originalContent == "{\"existing\": true}")

        // Verify nested file was renamed
        let renamedConfig: URL = tempDir.appendingPathComponent("config_1.json")
        #expect(FileManager.default.fileExists(atPath: renamedConfig.path))
        let renamedContent: String = try String(contentsOf: renamedConfig, encoding: .utf8)
        #expect(renamedContent == "{\"nested\": true}")
    }

    @Test("Clean up empty directories after restructuring")
    func testEmptyDirectoryCleanup() async throws {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-cleanup-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create deeply nested structure
        let deepPath: URL = tempDir
            .appendingPathComponent("level1")
            .appendingPathComponent("level2")
            .appendingPathComponent("level3")

        try FileManager.default.createDirectory(
            at: deepPath,
            withIntermediateDirectories: true
        )

        // Add a model file in deep directory
        let modelFile: URL = deepPath.appendingPathComponent("model.json")
        try "{\"model\": true}".write(to: modelFile, atomically: true, encoding: .utf8)
        // Add merges.txt to indicate this is the CoreML content directory
        let mergesFile: URL = deepPath.appendingPathComponent("merges.txt")
        try "test merges".write(to: mergesFile, atomically: true, encoding: .utf8)

        // Run restructuring
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Verify file was moved to root
        let rootModel: URL = tempDir.appendingPathComponent("model.json")
        #expect(FileManager.default.fileExists(atPath: rootModel.path))

        // Verify all nested directories were removed
        #expect(!FileManager.default.fileExists(atPath: deepPath.path))
        #expect(!FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("level1").path
        ))
    }

    @Test("Full CoreML download and restructure simulation")
    func testFullCoreMLWorkflow() async throws {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-workflow-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Step 1: Create a ZIP file with nested CoreML structure
        let zipContent: URL = tempDir.appendingPathComponent("zip-content")
        let modelDir: URL = zipContent.appendingPathComponent("split-einsum/v1-5_split-einsum")
        try FileManager.default.createDirectory(
            at: modelDir,
            withIntermediateDirectories: true
        )

        // Add model files
        try "merges content".write(
            to: modelDir.appendingPathComponent("merges.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "{\"config\": true}".write(
            to: modelDir.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        // Create ZIP
        let zipPath: URL = tempDir.appendingPathComponent("model.zip")
        try FileManager.default.zipItem(at: zipContent, to: zipPath)
        try FileManager.default.removeItem(at: zipContent)

        // Step 2: Extract ZIP (simulating download completion)
        let extractDir: URL = tempDir.appendingPathComponent("extracted")
        let extractor: ZipExtractor = ZipExtractor()
        _ = try await extractor.extractZip(at: zipPath, to: extractDir)

        print("\n📁 After extraction:")
        printDirectoryTree(at: extractDir, indent: 0)

        // Step 3: Restructure for CoreML
        try await extractor.restructureCoreMLFiles(at: extractDir)

        print("\n📁 After restructuring:")
        printDirectoryTree(at: extractDir, indent: 0)

        // Verify final structure is flat
        let mergesPath: URL = extractDir.appendingPathComponent("merges.txt")
        let configPath: URL = extractDir.appendingPathComponent("config.json")

        #expect(FileManager.default.fileExists(atPath: mergesPath.path))
        #expect(FileManager.default.fileExists(atPath: configPath.path))

        // Verify content is correct
        let mergesContent: String = try String(contentsOf: mergesPath, encoding: .utf8)
        #expect(mergesContent == "merges content")

        print("\nFull CoreML workflow test passed!")
    }

    // Helper function to print directory tree
    private func printDirectoryTree(at url: URL, indent: Int) {
        let prefix: String = String(repeating: "  ", count: indent)

        do {
            let contents: [URL] = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item: URL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let isDirectory: Bool = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                print("\(prefix)\(isDirectory ? "DIR" : "FILE") \(item.lastPathComponent)")

                if isDirectory {
                    printDirectoryTree(at: item, indent: indent + 1)
                }
            }
        } catch {
            print("\(prefix)Error reading directory: \(error)")
        }
    }
}
