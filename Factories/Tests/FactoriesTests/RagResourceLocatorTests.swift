import Foundation
@testable import Factories
import Testing

internal struct RagResourceLocatorTests {
    @Test("Locates model directory when required files exist")
    internal func testLocateModelDirectory() throws {
        let fileManager: FileManager = FileManager.default
        let tempRoot: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let modelDir: URL = tempRoot.appendingPathComponent(
            RagResourceLocator.modelDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)

        for file in RagResourceLocator.requiredFiles {
            let fileURL: URL = modelDir.appendingPathComponent(file)
            let created: Bool = fileManager.createFile(
                atPath: fileURL.path,
                contents: Data("test".utf8)
            )
            #expect(created)
        }

        let located: URL? = RagResourceLocator.locateModelDirectory(
            fileManager: fileManager,
            additionalSearchRoots: [tempRoot]
        )

        #expect(located?.standardizedFileURL == modelDir.standardizedFileURL)
    }

    @Test("Returns nil when required files are missing")
    internal func testLocateModelDirectoryReturnsNilWhenMissingFiles() throws {
        let fileManager: FileManager = FileManager.default
        let tempRoot: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let modelDir: URL = tempRoot.appendingPathComponent(
            RagResourceLocator.modelDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let located: URL? = RagResourceLocator.locateModelDirectory(
            fileManager: fileManager,
            additionalSearchRoots: [tempRoot]
        )

        #expect(located == nil)
    }
}
