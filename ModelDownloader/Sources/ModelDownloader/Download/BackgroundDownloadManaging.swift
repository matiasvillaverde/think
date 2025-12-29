import Abstractions
import Foundation

/// Protocol for background download management to enable test injection.
internal protocol BackgroundDownloadManaging: Sendable {
    func resumeAllDownloads() async -> [BackgroundDownloadHandle]
    func handleBackgroundCompletion(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) async
    func getActiveDownloads() -> [BackgroundDownloadStatus]
    func downloadModel(
        modelId: String,
        backend: SendableModel.Backend,
        files: [BackgroundFileDownload],
        options: BackgroundDownloadOptions,
        progressCallback: (@Sendable (DownloadProgress) -> Void)?
    ) throws -> BackgroundDownloadHandle
    func cancelDownload(id: UUID) async
}

extension BackgroundDownloadManager: BackgroundDownloadManaging {}
