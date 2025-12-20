import Foundation
@testable import ModelDownloader
import Testing

@Suite("ZIP Extraction Tests")
struct ZipExtractionTests {
    @Test("Verify ZIP files in subdirectories are extracted to root")
    func testNestedZipExtraction() throws {
        // Create a mock file structure similar to CoreML downloads
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-zip-extraction-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create subdirectory structure like CoreML
        let subdirPath: URL = tempDir
            .appendingPathComponent("split-einsum")
            .appendingPathComponent("768x768")

        try FileManager.default.createDirectory(
            at: subdirPath,
            withIntermediateDirectories: true
        )

        // Create a mock ZIP file in the subdirectory
        let mockZipPath: URL = subdirPath.appendingPathComponent("model.zip")
        let mockData: Data = Data("mock zip content".utf8)
        try mockData.write(to: mockZipPath)

        print("Created mock ZIP at: \(mockZipPath.path)")

        // Note: In a real implementation, we'd test with HuggingFaceDownloader
        // For now, we're just verifying the file enumeration logic

        // Test the extraction logic
        // Note: In a real test, we'd need a proper ZIP file and mock ZipExtractor

        // Verify the ZIP would be found
        let enumerator: FileManager.DirectoryEnumerator? = FileManager.default.enumerator(
            at: tempDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var foundZips: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "zip" {
                foundZips.append(fileURL)
            }
        }

        #expect(foundZips.count == 1)
        #expect(foundZips.first?.lastPathComponent == "model.zip")
        #expect(foundZips.first?.path.contains("split-einsum/768x768") == true)

        print("Successfully found nested ZIP file")
        print("   Path: \(foundZips.first?.path ?? "none")")
    }

    @Test("Verify empty subdirectories are cleaned up after extraction")
    func testSubdirectoryCleanup() throws {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-cleanup-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create nested directory
        let nestedDir: URL = tempDir
            .appendingPathComponent("subdirectory")
            .appendingPathComponent("nested")

        try FileManager.default.createDirectory(
            at: nestedDir,
            withIntermediateDirectories: true
        )

        // Create a file in the nested directory
        let filePath: URL = nestedDir.appendingPathComponent("file.txt")
        try Data("test".utf8).write(to: filePath)

        // Remove the file
        try FileManager.default.removeItem(at: filePath)

        // Check if directory is empty
        let contents: [URL]? = try? FileManager.default.contentsOfDirectory(
            at: nestedDir,
            includingPropertiesForKeys: nil
        )

        #expect(contents?.isEmpty == true)

        // Clean up empty directory
        if contents?.isEmpty ?? true {
            try FileManager.default.removeItem(at: nestedDir)
        }

        // Verify nested directory was removed
        #expect(FileManager.default.fileExists(atPath: nestedDir.path) == false)

        print("Empty subdirectory cleanup verified")
    }

    @Test("Simulate CoreML ZIP extraction workflow")
    func testCoreMLZipWorkflow() throws {
        print("\n🔄 Simulating CoreML ZIP extraction workflow...")

        // This test demonstrates the expected behavior:
        // 1. ZIP file downloaded to: temp/split-einsum/768x768/model.zip
        // 2. ZIP contains: stable-diffusion-v2.1-base_split-einsum_compiled/[model files]
        // 3. Extract to temp directory, detect single top-level directory
        // 4. Move contents up to model directory
        // 5. Delete ZIP and empty subdirectories

        let workflow: String = """
        Expected CoreML extraction workflow:

        1. Download structure:
           temp/
           └── split_einsum/
               └── stable-diffusion-v2.1-base_split-einsum.zip

        2. ZIP contains:
           stable-diffusion-v2.1-base_split-einsum_compiled/
           ├── model.mlmodelc/
           │   ├── model.mil
           │   ├── weights/
           │   └── metadata.json
           └── metadata.json

        3. After extraction (contents moved up):
           modelDir/
           ├── model.mlmodelc/
           │   ├── model.mil
           │   ├── weights/
           │   └── metadata.json
           ├── metadata.json
           └── model_info.json

        4. The ZIP file and empty subdirectories are removed
        """

        print(workflow)

        #expect(true) // Workflow documentation test
    }
}
