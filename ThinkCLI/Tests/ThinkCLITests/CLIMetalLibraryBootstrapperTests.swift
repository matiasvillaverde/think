import Foundation
@testable import ThinkCLI
import Testing

internal struct CLIMetalLibraryBootstrapperTests {
    @Test("Copies metallib from SwiftPM bundle into executable resources")
    internal func testBootstrapperCopiesMetallib() throws {
        let fileManager: FileManager = FileManager.default
        let tempRoot: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let execDir: URL = tempRoot.appendingPathComponent("bin", isDirectory: true)
        try fileManager.createDirectory(at: execDir, withIntermediateDirectories: true)
        let execURL: URL = execDir.appendingPathComponent("think")

        let bundleResources: URL = tempRoot
            .appendingPathComponent(".build/Build/Products/Debug", isDirectory: true)
            .appendingPathComponent("mlx-swift_Cmlx.bundle", isDirectory: true)
            .appendingPathComponent("Contents/Resources", isDirectory: true)
        try fileManager.createDirectory(at: bundleResources, withIntermediateDirectories: true)
        let sourceMetallib: URL = bundleResources.appendingPathComponent("default.metallib")
        let payload: Data = Data("metallib".utf8)
        let created: Bool = fileManager.createFile(atPath: sourceMetallib.path, contents: payload)
        #expect(created)

        let copied: Bool = CLIMetalLibraryBootstrapper.ensureMetallibAvailable(
            executableURL: execURL,
            fileManager: fileManager,
            searchRoots: [tempRoot]
        )

        #expect(copied)
        let target: URL = execDir.appendingPathComponent("Resources/default.metallib")
        #expect(fileManager.fileExists(atPath: target.path))
        let targetData: Data = try Data(contentsOf: target)
        #expect(targetData == payload)
    }

    @Test("Returns false when no metallib is found")
    internal func testBootstrapperReturnsFalseWhenMissing() throws {
        let fileManager: FileManager = FileManager.default
        let tempRoot: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let execDir: URL = tempRoot.appendingPathComponent("bin", isDirectory: true)
        try fileManager.createDirectory(at: execDir, withIntermediateDirectories: true)
        let execURL: URL = execDir.appendingPathComponent("think")

        let copied: Bool = CLIMetalLibraryBootstrapper.ensureMetallibAvailable(
            executableURL: execURL,
            fileManager: fileManager,
            searchRoots: [tempRoot]
        )

        #expect(copied == false)
    }
}
