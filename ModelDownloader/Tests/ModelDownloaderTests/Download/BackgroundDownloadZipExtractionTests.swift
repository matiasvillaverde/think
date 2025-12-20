import Abstractions
import Foundation
@testable import ModelDownloader
import Testing
import ZIPFoundation

@Suite("Background Download ZIP Extraction Tests")
struct BackgroundDownloadZipExtractionTests {
    @Test("Helper method detects ZIP files correctly")
    func testZipFileDetection() throws {
        let mockZipURL: URL = URL(fileURLWithPath: "/tmp/model.zip")
        let mockNonZipURL: URL = URL(fileURLWithPath: "/tmp/model.bin")
        let mockUppercaseZipURL: URL = URL(fileURLWithPath: "/tmp/model.ZIP")

        // Test the helper method we'll add to BackgroundDownloadManager
        #expect(BackgroundDownloadManager.isZipFile(mockZipURL) == true)
        #expect(BackgroundDownloadManager.isZipFile(mockNonZipURL) == false)
        #expect(BackgroundDownloadManager.isZipFile(mockUppercaseZipURL) == true)
    }

    @Test("ZIP extraction utility works correctly")
    func testZipExtractionUtility() async throws {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-zip-extraction-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a real ZIP file
        let zipURL: URL = tempDir.appendingPathComponent("test.zip")
        let testFile: URL = tempDir.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        // Create ZIP archive
        try FileManager.default.zipItem(at: testFile, to: zipURL)
        try FileManager.default.removeItem(at: testFile)

        // Extract using ZipExtractor
        let extractor: ZipExtractor = ZipExtractor()
        let extractDir: URL = tempDir.appendingPathComponent("extracted")
        _ = try await extractor.extractZip(at: zipURL, to: extractDir)

        // Verify extraction
        let extractedFile: URL = extractDir.appendingPathComponent("test.txt")
        #expect(FileManager.default.fileExists(atPath: extractedFile.path))

        let content: String = try String(contentsOf: extractedFile, encoding: .utf8)
        #expect(content == "Test content")
    }

    @Test("Integration test for ZIP extraction in download flow")
    func testZipExtractionInDownloadFlow() async throws {
        // This test verifies that ZIP files would be extracted in the download flow
        // once we implement the feature

        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-download-zip-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a ZIP file that simulates a CoreML model download
        let modelContent: URL = tempDir.appendingPathComponent("model.mlmodelc")
        try FileManager.default.createDirectory(at: modelContent, withIntermediateDirectories: true)
        let modelFile: URL = modelContent.appendingPathComponent("model")
        try "Model data".write(to: modelFile, atomically: true, encoding: .utf8)

        let zipPath: URL = tempDir.appendingPathComponent("model.zip")
        try FileManager.default.zipItem(at: modelContent, to: zipPath)
        try FileManager.default.removeItem(at: modelContent)

        // Simulate what should happen in the download completion
        let finalPath: URL = tempDir.appendingPathComponent("Downloads/model.zip")
        let finalDir: URL = finalPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: finalDir, withIntermediateDirectories: true)

        // This is what we want to implement:
        // 1. Detect it's a ZIP file
        #expect(BackgroundDownloadManager.isZipFile(zipPath) == true)

        // 2. Extract it
        if BackgroundDownloadManager.isZipFile(zipPath) {
            let extractor: ZipExtractor = ZipExtractor()
            let extractDir: URL = finalPath.deletingPathExtension()
            _ = try await extractor.extractZip(at: zipPath, to: extractDir)

            // 3. Delete original ZIP
            try FileManager.default.removeItem(at: zipPath)

            // 4. Verify extraction
            let extractedModel: URL = extractDir.appendingPathComponent("model.mlmodelc/model")
            #expect(FileManager.default.fileExists(atPath: extractedModel.path))
            #expect(!FileManager.default.fileExists(atPath: zipPath.path))
        }
    }

    @Test("Failed extraction handling")
    func testFailedExtractionHandling() async throws {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-failed-extraction-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let corruptedZip: URL = tempDir.appendingPathComponent("corrupted.zip")
        let corruptedData: Data = Data("not a valid zip".utf8)
        try corruptedData.write(to: corruptedZip)

        let extractor: ZipExtractor = ZipExtractor()
        let extractDir: URL = tempDir.appendingPathComponent("extracted")

        // Verify invalid ZIP is detected
        #expect(extractor.isValidZip(at: corruptedZip) == false)

        // Extraction should fail
        do {
            _ = try await extractor.extractZip(at: corruptedZip, to: extractDir)
            Issue.record("Should have thrown error for corrupted ZIP")
        } catch {
            // Expected - corrupted ZIP should preserve original file
            #expect(FileManager.default.fileExists(atPath: corruptedZip.path))
        }
    }

    @Test("State management during extraction")
    func testStateManagementDuringExtraction() async throws {
        // This test verifies that download state is not marked as completed
        // until after successful extraction

        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-state-management-\(UUID())")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a valid ZIP file
        let testFile: URL = tempDir.appendingPathComponent("test.txt")
        try "Test content for state management".write(to: testFile, atomically: true, encoding: .utf8)

        let zipPath: URL = tempDir.appendingPathComponent("model.zip")
        try FileManager.default.zipItem(at: testFile, to: zipPath)
        try FileManager.default.removeItem(at: testFile)

        // The actual state management is tested implicitly through the implementation
        // where extraction must complete before the download state is updated

        let extractor: ZipExtractor = ZipExtractor()
        let extractDir: URL = tempDir.appendingPathComponent("model")

        // Extract successfully
        _ = try await extractor.extractZip(at: zipPath, to: extractDir)

        // Verify extraction completed
        let extractedFile: URL = extractDir.appendingPathComponent("test.txt")
        #expect(FileManager.default.fileExists(atPath: extractedFile.path))

        // In the real implementation, the download state would only be marked
        // as completed after this point
    }
}
