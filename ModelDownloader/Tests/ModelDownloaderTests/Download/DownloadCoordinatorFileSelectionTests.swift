import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("DefaultDownloadCoordinator File Selection Tests", .serialized)
struct DownloadCoordinatorFileSelectionTests {
    @Test("Coordinator downloads the provided file list")
    func testUsesProvidedFileList() async throws {
        let tempDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelsDir: URL = tempDir.appendingPathComponent("models")
        try? FileManager.default.removeItem(at: tempDir)

        let identityService: ModelIdentityService = ModelIdentityService()
        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDir,
            temporaryDirectory: tempDir,
            identityService: identityService
        )
        let downloader: TrackingStreamingDownloader = TrackingStreamingDownloader()

        let modelLocation: String = "test/file-selection"
        let downloadDirectory: URL = fileManager.temporaryDirectory(for: modelLocation)
        let model: SendableModel = SendableModel(
            id: await identityService.generateModelId(for: modelLocation),
            ramNeeded: 1,
            modelType: .language,
            location: modelLocation,
            architecture: .unknown,
            backend: .gguf,
            locationKind: .huggingFace
        )

        let files: [ModelDownloadFile] = [
            ModelDownloadFile(
                url: try #require(URL(string: "https://example.com/\(modelLocation)/config.json")),
                relativePath: "config.json",
                size: 10
            ),
            ModelDownloadFile(
                url: try #require(URL(string: "https://example.com/\(modelLocation)/model.gguf")),
                relativePath: "model.gguf",
                size: 20
            )
        ]

        let coordinator: DefaultDownloadCoordinator = DefaultDownloadCoordinator(
            taskManager: DownloadTaskManager(),
            identityService: identityService,
            downloader: downloader,
            fileManager: fileManager
        ) { _ in files }

        try await coordinator.start(model: model)

        var state: DownloadStatus = await coordinator.state(for: model.location)
        var attempts: Int = 0
        while !state.isCompleted, attempts < 20 {
            try await Task.sleep(nanoseconds: 50_000_000)
            state = await coordinator.state(for: model.location)
            attempts += 1
        }

        #expect(state.isCompleted)

        let requestedList: [URL] = await downloader.requestedURLs()
        #expect(requestedList.count == files.count)
        let requestedURLs: Set<URL> = Set(requestedList)
        let expectedURLs: Set<URL> = Set(files.map(\.url))
        #expect(requestedURLs == expectedURLs)

        let destinationList: [URL] = await downloader.destinationURLs()
        #expect(destinationList.count == files.count)
        let requestedDestinations: Set<URL> = Set(destinationList)
        let expectedDestinations: Set<URL> = Set(
            files.map { downloadDirectory.appendingPathComponent($0.relativePath) }
        )
        #expect(requestedDestinations == expectedDestinations)

        try? FileManager.default.removeItem(at: tempDir)
    }
}

actor TrackingStreamingDownloader: StreamingDownloaderProtocol {
    private var requested: [URL] = []
    private var destinations: [URL] = []

    func requestedURLs() -> [URL] {
        requested
    }

    func destinationURLs() -> [URL] {
        destinations
    }

    func download(
        from url: URL,
        to destination: URL,
        headers _: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        requested.append(url)
        destinations.append(destination)
        await Task.yield()
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "test".write(to: destination, atomically: true, encoding: .utf8)
        progressHandler(1.0)
        return destination
    }

    func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        try await download(from: url, to: destination, headers: headers, progressHandler: progressHandler)
    }

    func cancel(url _: URL) async {
        await Task.yield()
    }

    func cancelAll() async {
        await Task.yield()
    }

    func pause(url _: URL) async {
        await Task.yield()
    }

    func pauseAll() async {
        await Task.yield()
    }

    func resume(url _: URL) async {
        await Task.yield()
    }

    func resumeAll() async {
        await Task.yield()
    }
}
