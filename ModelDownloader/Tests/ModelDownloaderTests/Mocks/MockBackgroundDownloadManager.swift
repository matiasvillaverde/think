import Abstractions
import Foundation
@testable import ModelDownloader

internal final class MockBackgroundDownloadManager: BackgroundDownloadManaging, @unchecked Sendable {
    private var statuses: [UUID: BackgroundDownloadStatus] = [:]

    func resumeAllDownloads() async -> [BackgroundDownloadHandle] {
        await Task.yield()
        return statuses.values.map(\.handle)
    }

    func handleBackgroundCompletion(
        identifier _: String,
        // Protocol requires escaping handler to match BackgroundDownloadManaging.
        // swiftlint:disable:next unneeded_escaping
        completionHandler: @escaping @Sendable () -> Void
    ) async {
        await Task.yield()
        completionHandler()
    }

    func getActiveDownloads() -> [BackgroundDownloadStatus] {
        Array(statuses.values)
    }

    func downloadModel(
        modelId: String,
        backend: SendableModel.Backend,
        files: [BackgroundFileDownload],
        options _: BackgroundDownloadOptions,
        progressCallback: (@Sendable (DownloadProgress) -> Void)?
    ) throws -> BackgroundDownloadHandle {
        let handle: BackgroundDownloadHandle = BackgroundDownloadHandle(
            id: UUID(),
            modelId: modelId,
            backend: backend,
            sessionIdentifier: "mock-background-session"
        )

        statuses[handle.id] = BackgroundDownloadStatus(
            handle: handle,
            state: .downloading,
            progress: 0.0
        )

        // Create placeholder files to allow finalization.
        for file in files {
            try FileManager.default.createDirectory(
                at: file.localPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: file.localPath.path) {
                try Data("mock".utf8).write(to: file.localPath)
            }
        }

        let totalBytes: Int64 = files.reduce(0) { $0 + $1.size }
        let progress: DownloadProgress = DownloadProgress(
            bytesDownloaded: totalBytes,
            totalBytes: max(totalBytes, 1),
            filesCompleted: files.count,
            totalFiles: files.count,
            currentFileName: files.last?.relativePath
        )

        progressCallback?(progress)

        statuses[handle.id] = BackgroundDownloadStatus(
            handle: handle,
            state: .completed,
            progress: 1.0
        )

        return handle
    }

    func cancelDownload(id: UUID) async {
        await Task.yield()
        statuses.removeValue(forKey: id)
    }

    deinit {
        // No cleanup required for the mock.
    }
}
