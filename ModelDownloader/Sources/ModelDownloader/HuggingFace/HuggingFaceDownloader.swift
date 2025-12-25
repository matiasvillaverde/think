import Abstractions
import Foundation

/// Production-ready HuggingFace model downloader with clean architecture
/// 
/// This implementation uses modern Swift patterns and components:
/// - `DownloadCoordinating` for download lifecycle management
/// - `DownloadTaskManager` for task tracking and cancellation
/// - `ModelIdentityService` for consistent UUID generation
/// - Clean error handling with typed errors
/// - Full support for pause/resume operations
internal actor HuggingFaceDownloader: HuggingFaceDownloaderProtocol {
    private let fileManager: ModelFileManagerProtocol
    private let hubAPI: HubAPI
    private let downloadCoordinator: DownloadCoordinating
    private let taskManager: DownloadTaskManager
    private let identityService: ModelIdentityService
    private let tokenManager: HFTokenManager
    private let configLoader: LanguageModelConfigurationFromHub
    private let validator: ModelValidator
    private let metadataExtractor: ModelMetadataExtractor
    private let diskSpaceValidator: DiskSpaceValidator
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "ModelDownloader",
        category: "huggingface-refactored"
    )

    /// Initialize refactored downloader with new components
    internal init(
        fileManager: ModelFileManagerProtocol,
        endpoint: String = "https://huggingface.co",
        urlSession: URLSession = .shared,
        enableProductionFeatures: Bool = true,
        downloadCoordinator: DownloadCoordinating? = nil,
        identityService: ModelIdentityService? = nil
    ) {
        self.fileManager = fileManager

        // Initialize new components
        self.taskManager = DownloadTaskManager()
        self.identityService = identityService ?? ModelIdentityService()

        // Initialize components
        let httpClient: DefaultHTTPClient = DefaultHTTPClient(urlSession: urlSession)
        self.tokenManager = HFTokenManager(httpClient: httpClient)

        if let injectedCoordinator = downloadCoordinator {
            // Use injected coordinator for testing
            self.downloadCoordinator = injectedCoordinator

            // Still need to setup HubAPI
            self.hubAPI = HubAPI(
                endpoint: endpoint,
                httpClient: httpClient,
                tokenManager: tokenManager
            )
        } else if enableProductionFeatures {
            // Create rate-limited HubAPI
            self.hubAPI = HubAPI.withRateLimiting(
                endpoint: endpoint,
                tokenManager: tokenManager
            )

            // Create download stack with all production features
            let streamingDownloader: StreamingDownloader = StreamingDownloader.withTimeout(urlSession: urlSession)
            let retryPolicy: ExponentialBackoffRetryPolicy = ExponentialBackoffRetryPolicy(
                maxRetries: 3,
                baseDelay: 1.0,
                maxDelay: 60.0,
                jitter: 0.1
            )
            let retryableDownloader: RetryableDownloader = RetryableDownloader(
                downloader: streamingDownloader,
                retryPolicy: retryPolicy
            )

            // Use new DefaultDownloadCoordinator
            self.downloadCoordinator = DefaultDownloadCoordinator(
                taskManager: taskManager,
                identityService: self.identityService,
                downloader: retryableDownloader,
                fileManager: fileManager
            )
        } else {
            // Test configuration
            self.hubAPI = HubAPI(
                endpoint: endpoint,
                httpClient: httpClient,
                tokenManager: tokenManager
            )

            let streamingDownloader: StreamingDownloader = StreamingDownloader(urlSession: urlSession)

            self.downloadCoordinator = DefaultDownloadCoordinator(
                taskManager: taskManager,
                identityService: self.identityService,
                downloader: streamingDownloader,
                fileManager: fileManager
            )
        }

        // Initialize components that depend on hubAPI
        self.configLoader = LanguageModelConfigurationFromHub(
            hubAPI: hubAPI,
            tokenManager: tokenManager
        )
        self.validator = ModelValidator()
        self.metadataExtractor = ModelMetadataExtractor()
        self.diskSpaceValidator = DiskSpaceValidator()
    }

    // MARK: - HuggingFaceDownloaderProtocol

    nonisolated internal func download(
        modelId: String,
        backend: SendableModel.Backend,
        customId: UUID? = nil
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self._performDownload(
                    modelId: modelId,
                    backend: backend,
                    customId: customId,
                    continuation: continuation
                )
            }
        }
    }

    private func _performDownload(
        modelId: String,
        backend: SendableModel.Backend,
        customId: UUID?,
        continuation: AsyncThrowingStream<DownloadEvent, Error>.Continuation
    ) async {
        do {
            await logger.info("Starting download for model: \(modelId)")

            // Generate consistent model ID from location
            let resolvedId: UUID
            if let customId: UUID {
                resolvedId = customId
            } else {
                resolvedId = await identityService.generateModelId(for: modelId)
            }

            // Create SendableModel for the new coordinator
            let model: SendableModel = SendableModel(
                id: resolvedId,
                ramNeeded: 0, // Will be determined from config
                modelType: .language, // Will be determined from config
                location: modelId,
                architecture: .unknown, // Will be determined from config
                backend: backend,
                locationKind: .huggingFace
            )

            // Check if model already exists
            let currentState: DownloadStatus = await downloadCoordinator.state(for: modelId)
            if case .completed = currentState {
                await logger.info("Model already downloaded: \(modelId)")

                // Get model info
                if let modelInfo: ModelInfo = try await fileManager.listDownloadedModels()
                    .first(where: { $0.id == resolvedId }) {
                    continuation.yield(.completed(modelInfo))
                }
                continuation.finish()
                return
            }

            // Start download using new coordinator
            try await downloadCoordinator.start(model: model)

            // Monitor download progress
            var lastProgress: Double = 0
            while true {
                let state: DownloadStatus = await downloadCoordinator.state(for: modelId)

                switch state {
                case .notStarted:
                    // Should not happen after start
                    break

                case .downloading(let progress):
                    if progress != lastProgress {
                        lastProgress = progress
                        let downloadProgress: DownloadProgress = DownloadProgress(
                            bytesDownloaded: Int64(progress * 100_000_000), // Estimate
                            totalBytes: 100_000_000, // Estimate
                            filesCompleted: 0,
                            totalFiles: 1,
                            currentFileName: modelId
                        )
                        continuation.yield(.progress(downloadProgress))
                    }

                case .paused(let progress):
                    // Handle pause if needed
                    await logger.info("Download paused at \(progress)")

                case .completed:
                    // Download completed
                    if let modelInfo: ModelInfo = try await fileManager.listDownloadedModels()
                        .first(where: { $0.id == resolvedId }) {
                        continuation.yield(.completed(modelInfo))
                    }
                    continuation.finish()
                    return

                case .failed(let error):
                    throw ModelDownloadError.unknown(error)
                }

                // Small delay to avoid busy waiting
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        } catch {
            await logger.error("Download failed for model: \(modelId), error: \(error)")
            continuation.finish(throwing: error)
        }
    }

    internal func cancelDownload(for modelId: String) async {
        await logger.info("Cancelling download for model: \(modelId)")
        await downloadCoordinator.cancel(repositoryId: modelId)
    }

    internal func pauseDownload(for modelId: String) async {
        await logger.info("Pausing download for model: \(modelId)")
        try? await downloadCoordinator.pause(repositoryId: modelId)
    }

    internal func resumeDownload(for modelId: String) async {
        await logger.info("Resuming download for model: \(modelId)")
        try? await downloadCoordinator.resume(repositoryId: modelId)
    }

    internal func modelExists(modelId: String) async throws -> Bool {
        let repo: Repository = Repository(id: modelId)

        do {
            let files: [FileInfo] = try await hubAPI.listFiles(
                repo: repo,
                revision: "main",
                includePattern: nil,
                excludePattern: nil
            )
            return !files.isEmpty
        } catch {
            if case HuggingFaceError.repositoryNotFound = error {
                return false
            }
            throw error
        }
    }

    internal func getModelMetadata(
        modelId: String,
        backend: SendableModel.Backend
    ) async throws -> [FileMetadata] {
        let repo: Repository = Repository(id: modelId)

        // List all files
        let files: [FileInfo] = try await hubAPI.listFiles(
            repo: repo,
            revision: "main",
            includePattern: nil,
            excludePattern: nil
        )

        // Filter by format
        let matchingFiles: [FileInfo] = await filterFilesForBackend(files, backend: backend)

        // Get detailed metadata for each file
        var metadata: [FileMetadata] = []
        for file: FileInfo in matchingFiles {
            let fileMeta: FileMetadata = try await hubAPI.fileMetadata(
                repo: repo,
                path: file.path,
                revision: "main"
            )
            metadata.append(fileMeta)
        }

        return metadata
    }

    internal func getModelFiles(
        modelId: String,
        backend: SendableModel.Backend
    ) async throws -> [FileDownloadInfo] {
        await logger.debug("Getting model files for background download", metadata: [
            "modelId": modelId,
            "backend": backend.rawValue
        ])

        let repo: Repository = Repository(id: modelId)

        // List all files in repository
        let files: [FileInfo] = try await hubAPI.listFiles(
            repo: repo,
            revision: "main",
            includePattern: nil,
            excludePattern: nil
        )

        // Filter files by format
        let matchingFiles: [FileInfo] = await filterFilesForBackend(files, backend: backend)

        // Create temporary directory to get local paths
        let tempDir: URL = fileManager.temporaryDirectory(for: modelId)

        // Convert to FileDownloadInfo
        var downloadFiles: [FileDownloadInfo] = []
        for file: FileInfo in matchingFiles {
            let downloadURL: URL = repo.downloadURL(path: file.path, revision: "main")
            let localPath: URL = tempDir.appendingPathComponent(file.path)

            let downloadInfo: FileDownloadInfo = FileDownloadInfo(
                url: downloadURL,
                localPath: localPath,
                size: file.size,
                path: file.path
            )

            downloadFiles.append(downloadInfo)
        }

        await logger.debug("Prepared files for background download", metadata: [
            "modelId": modelId,
            "fileCount": downloadFiles.count
        ])

        return downloadFiles
    }

    // MARK: - Utility Methods

    private func buildAuthHeaders() async -> [String: String] {
        var headers: [String: String] = [:]
        if let token: String = await tokenManager.getToken() {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    private func filterFilesForBackend(
        _ files: [FileInfo],
        backend: SendableModel.Backend
    ) async -> [FileInfo] {
        // Use specialized file selectors for intelligent file selection
        let factory: FileSelectorFactory = FileSelectorFactory.shared
        guard let selector: FileSelectorProtocol = await factory.createSelector(for: backend) else {
            // For backends without specialized selectors (like MLX), use pattern matching
            return files.filter { file in
                backend.filePatterns.contains { pattern in
                    file.path.hasSuffix(pattern.replacingOccurrences(of: "*", with: ""))
                }
            }
        }

        // Convert FileInfo to ModelFile for selector
        let modelFiles: [ModelFile] = files.map { file in
            ModelFile(
                path: file.path,
                size: file.size == 0 ? nil : file.size,
                sha: nil
            )
        }

        // Use selector to intelligently choose files
        let selectedModelFiles: [ModelFile] = await selector.selectFiles(from: modelFiles)

        // Convert back to FileInfo
        return selectedModelFiles.map { modelFile in
            FileInfo(
                path: modelFile.path,
                size: modelFile.size ?? 0,
                lfs: nil
            )
        }
    }

    // MARK: - Factory Method

    /// Create a production-ready downloader with all features enabled
    internal static func createProductionDownloader(
        fileManager: ModelFileManagerProtocol,
        identityService: ModelIdentityService? = nil
    ) -> HuggingFaceDownloader {
        HuggingFaceDownloader(
            fileManager: fileManager,
            enableProductionFeatures: true,
            identityService: identityService
        )
    }
}
