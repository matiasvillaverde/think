import Abstractions
import Foundation
@testable import ModelDownloader

@MainActor
internal struct TestDownloaderContext {
    let baseDirectory: URL
    let fileManager: ModelFileManager
    let mockDownloader: MockHuggingFaceDownloader
    let backgroundManager: MockBackgroundDownloadManager
    let downloader: ModelDownloader

    init(communityExplorer: CommunityModelsExplorerProtocol = MockCommunityModelsExplorer()) {
        baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("modeldownloader-tests-\(UUID().uuidString)")

        let modelsDir: URL = baseDirectory.appendingPathComponent("models")
        let tempDir: URL = baseDirectory.appendingPathComponent("downloads")

        fileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir
        )
        mockDownloader = MockHuggingFaceDownloader(fileManager: fileManager)
        backgroundManager = MockBackgroundDownloadManager()
        downloader = ModelDownloader(
            fileManager: fileManager,
            downloader: mockDownloader,
            backgroundDownloadManager: backgroundManager,
            communityExplorer: communityExplorer
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
