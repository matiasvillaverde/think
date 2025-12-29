import Abstractions
import Foundation
@testable import ModelDownloader

internal final class MockHuggingFaceDownloader: HuggingFaceDownloaderProtocol, @unchecked Sendable {
    struct FixtureFile {
        let path: String
        let data: Data
        let size: Int64
    }

    struct FixtureModel {
        let modelId: String
        let backend: SendableModel.Backend
        let name: String
        let files: [FixtureFile]
    }

    private let fileManager: ModelFileManagerProtocol
    private let state: State = State()
    private let cancellationState: CancellationState = CancellationState()

    init(fileManager: ModelFileManagerProtocol) {
        self.fileManager = fileManager
    }

    deinit {}

    func registerFixture(_ fixture: FixtureModel) async {
        await Task.yield()
        let key: String = fixtureKey(modelId: fixture.modelId, backend: fixture.backend)
        await state.setFixture(fixture, key: key)
    }

    func setDownloadDelayNanoseconds(_ delay: UInt64?) async {
        await Task.yield()
        await state.setDelay(delay)
    }

    func download(
        modelId: String,
        backend: SendableModel.Backend,
        customId _: UUID?
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                defer {
                    Task {
                        await cancellationState.clear(modelId)
                    }
                }
                if let downloadError = await state.currentDownloadError() {
                    continuation.finish(throwing: downloadError)
                    return
                }

                if await cancellationState.isCancelled(modelId) {
                    continuation.finish(throwing: CancellationError())
                    return
                }

                let key: String = fixtureKey(modelId: modelId, backend: backend)
                guard let fixture: FixtureModel = await state.fixture(for: key) else {
                    continuation.finish(throwing: HuggingFaceError.repositoryNotFound)
                    return
                }

                do {
                    if let delay = await state.delay() {
                        try await Task.sleep(nanoseconds: delay)
                        try Task.checkCancellation()
                        if await cancellationState.isCancelled(modelId) {
                            throw CancellationError()
                        }
                    }
                    let tempDir: URL = fileManager.temporaryDirectory(for: modelId)
                    try FileManager.default.createDirectory(
                        at: tempDir,
                        withIntermediateDirectories: true
                    )

                    var totalSize: Int64 = 0
                    for file in fixture.files {
                        let fileURL: URL = tempDir.appendingPathComponent(file.path)
                        try FileManager.default.createDirectory(
                            at: fileURL.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                        try file.data.write(to: fileURL)
                        totalSize += file.size
                    }

                    let progress: DownloadProgress = DownloadProgress(
                        bytesDownloaded: totalSize,
                        totalBytes: max(totalSize, 1),
                        filesCompleted: fixture.files.count,
                        totalFiles: fixture.files.count,
                        currentFileName: fixture.files.last?.path
                    )
                    continuation.yield(.progress(progress))

                    if await cancellationState.isCancelled(modelId) {
                        throw CancellationError()
                    }

                    let modelInfo: ModelInfo = try await fileManager.finalizeDownload(
                        repositoryId: modelId,
                        name: fixture.name,
                        backend: backend,
                        from: tempDir,
                        totalSize: totalSize
                    )

                    continuation.yield(.completed(modelInfo))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func pauseDownload(for _: String) async {
        await Task.yield()
    }

    func resumeDownload(for _: String) async {
        await Task.yield()
    }

    func cancelDownload(for modelId: String) async {
        await Task.yield()
        await cancellationState.cancel(modelId)
    }

    func modelExists(modelId: String) async throws -> Bool {
        try await Task.sleep(nanoseconds: 0)
        return await fileManager.modelExists(repositoryId: modelId)
    }

    func getModelMetadata(modelId: String, backend: SendableModel.Backend) async throws -> [FileMetadata] {
        await Task.yield()
        let key: String = fixtureKey(modelId: modelId, backend: backend)
        guard let fixture: FixtureModel = await state.fixture(for: key) else {
            throw HuggingFaceError.repositoryNotFound
        }

        return fixture.files.map { file in
            FileMetadata(filename: file.path, size: file.size)
        }
    }

    func getModelFiles(modelId: String, backend: SendableModel.Backend) async throws -> [FileDownloadInfo] {
        await Task.yield()
        let key: String = fixtureKey(modelId: modelId, backend: backend)
        guard let fixture: FixtureModel = await state.fixture(for: key) else {
            throw HuggingFaceError.repositoryNotFound
        }

        let baseDir: URL = fileManager.temporaryDirectory(for: modelId)
        return fixture.files.map { file in
            FileDownloadInfo(
                url: URL(string: "https://example.com/\(file.path)")!,
                localPath: baseDir.appendingPathComponent(file.path),
                size: file.size,
                path: file.path
            )
        }
    }

    private func fixtureKey(modelId: String, backend: SendableModel.Backend) -> String {
        "\(modelId)|\(backend.rawValue)"
    }

    private actor State {
        private var fixtures: [String: FixtureModel] = [:]
        private var downloadError: Error?
        private var downloadDelayNanoseconds: UInt64?

        func setFixture(_ fixture: FixtureModel, key: String) {
            fixtures[key] = fixture
        }

        func fixture(for key: String) -> FixtureModel? {
            fixtures[key]
        }

        func setDelay(_ delay: UInt64?) {
            downloadDelayNanoseconds = delay
        }

        func delay() -> UInt64? {
            downloadDelayNanoseconds
        }

        func setDownloadError(_ error: Error?) {
            downloadError = error
        }

        func currentDownloadError() -> Error? {
            downloadError
        }
    }

    private actor CancellationState {
        private var cancelledModelIds: Set<String> = []

        func cancel(_ modelId: String) {
            cancelledModelIds.insert(modelId)
        }

        func isCancelled(_ modelId: String) -> Bool {
            cancelledModelIds.contains(modelId)
        }

        func clear(_ modelId: String) {
            cancelledModelIds.remove(modelId)
        }
    }
}
