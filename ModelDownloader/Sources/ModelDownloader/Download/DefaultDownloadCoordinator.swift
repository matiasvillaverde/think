import Abstractions
import Foundation
import os.log

/// Default implementation of DownloadCoordinating protocol
///
/// This coordinator manages the download lifecycle using the provided dependencies
/// for task management, file handling, and actual downloading.
public actor DefaultDownloadCoordinator: DownloadCoordinating {
    private let taskManager: DownloadTaskManager
    private let identityService: ModelIdentityService
    private let downloader: StreamingDownloaderProtocol
    private let fileManager: ModelFileManagerProtocol
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "ModelDownloader",
        category: "Coordinator"
    )

    // Track download states and URLs by repository ID
    private var downloadStates: [String: DownloadStatus] = [:]
    private var downloadURLs: [String: URL] = [:]

    public init(
        taskManager: DownloadTaskManager,
        identityService: ModelIdentityService,
        downloader: StreamingDownloaderProtocol,
        fileManager: ModelFileManagerProtocol
    ) {
        self.taskManager = taskManager
        self.identityService = identityService
        self.downloader = downloader
        self.fileManager = fileManager
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

        // Create download URL
        let urlString: String = "https://huggingface.co/\(model.location)/resolve/main/model.bin"
        guard let downloadURL: URL = URL(string: urlString) else {
            throw ModelDownloadError.invalidURL(urlString)
        }

        // Create destination path
        let destinationURL: URL = fileManager.temporaryDirectory(for: repositoryId).appendingPathComponent("model.bin")

        // Store download URL for pause/resume
        downloadURLs[repositoryId] = downloadURL

        // Update state
        downloadStates[repositoryId] = .downloading(progress: 0.0)

        // Create download task
        let task: Task<Void, Never> = Task<Void, Never> {
            do {
                // Use the shared StreamingDownloader instance
                let headers: [String: String] = ["User-Agent": "Think/1.0"]
                let progressHandler: @Sendable (Double) -> Void = { [weak self] (progress: Double) in
                    Task { [weak self] in
                        await self?.updateDownloadProgress(repositoryId: repositoryId, progress: progress)
                    }
                }

                let result: URL = try await downloader.download(
                    from: downloadURL,
                    to: destinationURL,
                    headers: headers,
                    progressHandler: progressHandler
                )

                // Download completed successfully - finalize the download
                let modelInfo: ModelInfo = try await fileManager.finalizeDownload(
                    repositoryId: model.location,
                    name: model.location,
                    backend: model.backend,
                    from: result,
                    totalSize: 0 // Will be calculated by finalizeDownload
                )

                downloadStates[repositoryId] = .completed
                downloadURLs.removeValue(forKey: repositoryId)
                await logger.info("Download completed and finalized for \(model.location), modelInfo: \(modelInfo.id)")
            } catch {
                downloadStates[repositoryId] = .failed(error: error.localizedDescription)
                downloadURLs.removeValue(forKey: repositoryId)
                await logger.error("Download error for \(model.location): \(error)")
            }
        }

        // Store task
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

        // Pause the download using the URL
        if let downloadURL = downloadURLs[repositoryId] {
            await downloader.pause(url: downloadURL)
            downloadStates[repositoryId] = .paused(progress: progress)
        } else {
            throw ModelDownloadError.unknown("Download URL not found")
        }
    }

    public func resume(repositoryId: String) async throws {
        await logger.info("Resuming download for repository: \(repositoryId)")

        guard let currentState = downloadStates[repositoryId] else {
            throw ModelDownloadError.unknown("Model not found: \(repositoryId)")
        }

        guard case .paused(let progress) = currentState else {
            throw ModelDownloadError.unknown("Cannot resume - not paused")
        }

        // Resume the download using the URL
        if let downloadURL = downloadURLs[repositoryId] {
            await downloader.resume(url: downloadURL)
            downloadStates[repositoryId] = .downloading(progress: progress)
        } else {
            throw ModelDownloadError.unknown("Download URL not found")
        }
    }

    public func cancel(repositoryId: String) async throws {
        await logger.info("Canceling download for repository: \(repositoryId)")

        // Cancel the task
        await taskManager.cancel(repositoryId: repositoryId)

        // Cancel the download using the URL
        if let downloadURL = downloadURLs[repositoryId] {
            await downloader.cancel(url: downloadURL)
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
        downloadStates[repositoryId] = .downloading(progress: progress)
        await logger.debug("Download progress for model \(repositoryId): \(progress)")
    }

    // Internal helper for tests
    func updateState(for repositoryId: String, state: DownloadStatus) {
        downloadStates[repositoryId] = state
    }
}
