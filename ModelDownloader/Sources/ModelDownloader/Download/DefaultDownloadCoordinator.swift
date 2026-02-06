import Abstractions
import Foundation
import os.log

/// Default implementation of DownloadCoordinating protocol
///
/// This coordinator manages the download lifecycle using the provided dependencies
/// for task management, file handling, and actual downloading.
public actor DefaultDownloadCoordinator: DownloadCoordinating {
    public typealias ModelFilesProvider = @Sendable (SendableModel) async throws -> [ModelDownloadFile]

    private let taskManager: DownloadTaskManager
    private let identityService: ModelIdentityService
    private let downloader: StreamingDownloaderProtocol
    private let fileManager: ModelFileManagerProtocol
    private let modelFilesProvider: ModelFilesProvider
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "ModelDownloader",
        category: "Coordinator"
    )

    // Track download states and URLs by repository ID
    private var downloadStates: [String: DownloadStatus] = [:]
    private var downloadURLs: [String: [URL]] = [:]

    public init(
        taskManager: DownloadTaskManager,
        identityService: ModelIdentityService,
        downloader: StreamingDownloaderProtocol,
        fileManager: ModelFileManagerProtocol,
        modelFilesProvider: @escaping ModelFilesProvider = DefaultDownloadCoordinator.missingFilesProvider
    ) {
        self.taskManager = taskManager
        self.identityService = identityService
        self.downloader = downloader
        self.fileManager = fileManager
        self.modelFilesProvider = modelFilesProvider
    }

    public func start(model: SendableModel) async throws {
        await logger.info("Starting download for model: \(model.location)")

        let repositoryId: String = model.location

        // Check if already downloading
        if let currentState = downloadStates[repositoryId] {
            switch currentState {
            case .downloading:
                throw ModelDownloadError.unknown("Already downloading")

            case .completed:
                await logger.info("Model already downloaded: \(model.location)")
                return

            default:
                break
            }
        }

        let tempDirectory: URL = fileManager.temporaryDirectory(for: repositoryId)
        let downloadFiles: [FileDownloadInfo] = try await buildDownloadFiles(
            for: model,
            tempDirectory: tempDirectory
        )

        downloadURLs[repositoryId] = downloadFiles.map(\.url)
        downloadStates[repositoryId] = .downloading(progress: 0.0)

        let task: Task<Void, Never> = Task { [weak self] in
            await self?.performDownload(
                repositoryId: repositoryId,
                model: model,
                tempDirectory: tempDirectory,
                files: downloadFiles
            )
        }

        await taskManager.store(task: task, for: repositoryId)
    }

    public func pause(repositoryId: String) async throws {
        await logger.info("Pausing download for repository: \(repositoryId)")

        guard let currentState = downloadStates[repositoryId] else {
            throw ModelDownloadError.unknown("Model not found: \(repositoryId)")
        }

        guard case .downloading(let progress) = currentState else {
            throw ModelDownloadError.unknown("Cannot pause - not downloading")
        }

        guard let urls = downloadURLs[repositoryId], !urls.isEmpty else {
            throw ModelDownloadError.unknown("Download URLs not found")
        }

        for url in urls {
            await downloader.pause(url: url)
        }
        downloadStates[repositoryId] = .paused(progress: progress)
    }

    public func resume(repositoryId: String) async throws {
        await logger.info("Resuming download for repository: \(repositoryId)")

        guard let currentState = downloadStates[repositoryId] else {
            throw ModelDownloadError.unknown("Model not found: \(repositoryId)")
        }

        guard case .paused(let progress) = currentState else {
            throw ModelDownloadError.unknown("Cannot resume - not paused")
        }

        guard let urls = downloadURLs[repositoryId], !urls.isEmpty else {
            throw ModelDownloadError.unknown("Download URLs not found")
        }

        for url in urls {
            await downloader.resume(url: url)
        }
        downloadStates[repositoryId] = .downloading(progress: progress)
    }

    public func cancel(repositoryId: String) async {
        await logger.info("Canceling download for repository: \(repositoryId)")

        // Cancel the task
        await taskManager.cancel(repositoryId: repositoryId)

        if let urls = downloadURLs[repositoryId] {
            for url in urls {
                await downloader.cancel(url: url)
            }
        }

        // Cleanup
        downloadURLs.removeValue(forKey: repositoryId)
        downloadStates[repositoryId] = .notStarted
    }

    public func state(for repositoryId: String) -> DownloadStatus {
        downloadStates[repositoryId] ?? .notStarted
    }

    // Private helper to update download progress
    private func updateDownloadProgress(repositoryId: String, progress: Double) async {
        guard case .downloading = downloadStates[repositoryId] else {
            return
        }
        downloadStates[repositoryId] = .downloading(progress: progress)
        await logger.debug("Download progress for model \(repositoryId): \(progress)")
    }

    private func buildDownloadFiles(
        for model: SendableModel,
        tempDirectory: URL
    ) async throws -> [FileDownloadInfo] {
        let modelFiles: [ModelDownloadFile] = try await modelFilesProvider(model)
        guard !modelFiles.isEmpty else {
            throw ModelDownloadError.unknown("No downloadable files for \(model.location)")
        }

        return modelFiles.map { file in
            FileDownloadInfo(
                url: file.url,
                localPath: tempDirectory.appendingPathComponent(file.relativePath),
                size: file.size,
                path: file.relativePath
            )
        }
    }

    private func performDownload(
        repositoryId: String,
        model: SendableModel,
        tempDirectory: URL,
        files: [FileDownloadInfo]
    ) async {
        do {
            let headers: [String: String] = ["User-Agent": "Think/1.0"]
            let progressHandler: @Sendable (DownloadProgress) -> Void = { [weak self] progress in
                Task { [weak self] in
                    await self?.updateDownloadProgress(
                        repositoryId: repositoryId,
                        progress: progress.fractionCompleted
                    )
                }
            }

            let coordinator: DownloadCoordinator = DownloadCoordinator(downloader: downloader)
            let results: [DownloadResult] = try await coordinator.downloadFiles(
                files,
                headers: headers,
                progressHandler: progressHandler
            )

            if let failure = results.first(where: { !$0.success }) {
                let failureMessage: String = failure.error?.localizedDescription
                    ?? "Download failed for \(failure.url.lastPathComponent)"
                throw ModelDownloadError.unknown(failureMessage)
            }

            let totalSize: Int64 = files.reduce(0) { $0 + $1.size }
            let modelInfo: ModelInfo = try await fileManager.finalizeDownload(
                repositoryId: model.location,
                name: model.location,
                backend: model.backend,
                from: tempDirectory,
                totalSize: totalSize
            )

            downloadStates[repositoryId] = .completed
            downloadURLs.removeValue(forKey: repositoryId)
            await logger.info(
                "Download completed and finalized for \(model.location), modelInfo: \(modelInfo.id)"
            )
        } catch {
            downloadStates[repositoryId] = .failed(error: error.localizedDescription)
            downloadURLs.removeValue(forKey: repositoryId)
            await logger.error("Download error for \(model.location): \(error)")
        }
    }

    @usableFromInline
    static func missingFilesProvider(_: SendableModel) async throws -> [ModelDownloadFile] {
        await Task.yield()
        throw ModelDownloadError.unknown("Model files provider not configured")
    }

    // Internal helper for tests
    func updateState(for repositoryId: String, state: DownloadStatus) {
        downloadStates[repositoryId] = state
    }
}
