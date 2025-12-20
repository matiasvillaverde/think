import Foundation
@testable import ModelDownloader
import Testing

@Suite("File Extensions Tests")
struct FileExtensionsTests {
    @Test("URL extensions work correctly")
    func testURLExtensions() throws {
        // Test file URL
        let fileURL: URL = URL(fileURLWithPath: "/tmp/test.txt")
        #expect(fileURL.normalizedPathExtension == "txt")
        #expect(!fileURL.isZipFile)
        #expect(!fileURL.isCoreMLModel)

        // Test directory URL - use an actual existing directory
        let dirURL: URL = FileManager.default.temporaryDirectory
        #expect(dirURL.isDirectory)

        // Test ZIP file
        let zipURL: URL = URL(fileURLWithPath: "/tmp/model.zip")
        #expect(zipURL.isZipFile)
        #expect(zipURL.normalizedPathExtension == "zip")

        // Test CoreML files
        let mlmodelURL: URL = URL(fileURLWithPath: "/tmp/model.mlmodel")
        #expect(mlmodelURL.isCoreMLModel)

        let mlmodelcURL: URL = URL(fileURLWithPath: "/tmp/model.mlmodelc")
        #expect(mlmodelcURL.isCoreMLModel)

        let mlpackageURL: URL = URL(fileURLWithPath: "/tmp/model.mlpackage")
        #expect(mlpackageURL.isCoreMLModel)
    }

    @Test("FileManager extensions work correctly")
    func testFileManagerExtensions() throws {
        let fileManager: FileManager = FileManager.default
        let tempDir: URL = fileManager.temporaryDirectory

        // Test directory exists
        #expect(fileManager.directoryExists(at: tempDir))

        // Test non-existent directory
        let nonExistentURL: URL = tempDir.appendingPathComponent(UUID().uuidString)
        #expect(!fileManager.directoryExists(at: nonExistentURL))
    }

    @Test("Int64 formatting extensions work correctly")
    func testInt64FormattingExtensions() throws {
        let kilobyte: Int64 = 1_024
        let megabyte: Int64 = 1_024 * 1_024
        let gigabyte: Int64 = 1_024 * 1_024 * 1_024

        // Test formatted bytes
        #expect(kilobyte.formattedBytes == "1 KB")
        #expect(megabyte.formattedBytes == "1 MB")
        #expect(gigabyte.formattedBytes == "1 GB")

        // Test formatted megabytes
        #expect(megabyte.formattedMegabytes == "1.0 MB")
        #expect((megabyte * 512).formattedMegabytes == "512.0 MB")

        // Test formatted gigabytes
        #expect(gigabyte.formattedGigabytes == "1.00 GB")
        #expect((gigabyte * 2).formattedGigabytes == "2.00 GB")
    }

    @Test("String extensions work correctly")
    func testStringExtensions() throws {
        // Test safe directory name
        #expect("user/model".safeDirectoryName == "user_model")
        #expect("path:with:colons".safeDirectoryName == "path_with_colons")
        #expect("path\\with\\backslashes".safeDirectoryName == "path_with_backslashes")

        // Test valid file extension
        #expect("txt".isValidFileExtension)
        #expect("mlmodel".isValidFileExtension)
        #expect(!"".isValidFileExtension)
        #expect(!"path/file".isValidFileExtension)
        #expect(!"verylongextension".isValidFileExtension)
    }

    @Test("Array<URL> extensions work correctly")
    func testArrayURLExtensions() throws {
        let tempDir: URL = FileManager.default.temporaryDirectory
        let testDir: URL = tempDir.appendingPathComponent(UUID().uuidString)

        // Create test directory
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir) }

        // Create test files
        let file1: URL = testDir.appendingPathComponent("file1.txt")
        let file2: URL = testDir.appendingPathComponent("file2.txt")
        let subDir: URL = testDir.appendingPathComponent("subdir", isDirectory: true)

        try "test1".write(to: file1, atomically: true, encoding: .utf8)
        try "test22".write(to: file2, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        // Test filtering
        let urls: [URL] = [file1, file2, subDir]
        let files: [URL] = urls.regularFiles
        let dirs: [URL] = urls.directories

        #expect(files.count == 2)
        #expect(dirs.count == 1)

        // Test total size
        let totalSize: Int64 = files.totalSize
        #expect(totalSize == 11) // "test1" (5) + "test22" (6) = 11 bytes

        // Test sorting by size
        let sortedBySize: [URL] = files.sortedBySize()
        #expect(sortedBySize.first?.lastPathComponent == "file2.txt") // Larger file first
        #expect(sortedBySize.last?.lastPathComponent == "file1.txt")

        let sortedBySizeAsc: [URL] = files.sortedBySize(ascending: true)
        #expect(sortedBySizeAsc.first?.lastPathComponent == "file1.txt") // Smaller file first
    }
}
