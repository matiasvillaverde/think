import Abstractions
import Foundation

/// ModelDownloader - Production-ready Swift package for downloading AI models
/// 
/// This package provides:
/// - Multi-format model support (MLX, GGUF, CoreML)
/// - Accurate byte-based progress tracking with throttling
/// - HuggingFace Hub integration with authentication support
/// - Background downloads with pause/resume capabilities
/// - ZIP extraction for CoreML models
/// - Thread-safe actor-based architecture
/// - Retry logic with exponential backoff
/// - Rate limiting for API compliance
/// - Comprehensive error handling with typed errors

/// Main facade for the ModelDownloader package
/// 
/// Provides convenient access to all download and file management functionality
public struct ModelDownloader: ModelDownloaderProtocol {
    /// Default shared instance with standard configuration
    public static let shared: ModelDownloader = Self()

    /// File manager for model storage operations
    private let fileManager: ModelFileManagerProtocol

    /// HuggingFace downloader for fetching models
    private let downloader: HuggingFaceDownloaderProtocol

    /// Background download manager
    private let backgroundDownloadManager: BackgroundDownloadManaging

    /// Community explorer for backend detection
    private let communityExplorer: CommunityModelsExplorerProtocol

    /// Logger for this component
    private let logger: ModelDownloaderLogger

    /// Create a ModelDownloader with custom configuration
    /// - Parameters:
    ///   - modelsDirectory: Directory where models will be stored
    ///   - temporaryDirectory: Directory for temporary files during download
    public init(
        modelsDirectory: URL = ModelPath.defaultModelsDirectory,
        temporaryDirectory: URL = ModelPath.defaultTemporaryDirectory
    ) {
        // Create shared identity service for consistent UUID generation
        let identityService: ModelIdentityService = ModelIdentityService()

        let fileManager: ModelFileManager = ModelFileManager(
            modelsDirectory: modelsDirectory,
            temporaryDirectory: temporaryDirectory,
            identityService: identityService
        )

        self.fileManager = fileManager

        // Use the production downloader with shared identity service
        self.downloader = HuggingFaceDownloader(
            fileManager: fileManager,
            enableProductionFeatures: true,
            identityService: identityService
        )

        self.backgroundDownloadManager = BackgroundDownloadManager.shared
        self.communityExplorer = CommunityModelsExplorer()

        self.logger = ModelDownloaderLogger(
            subsystem: "ModelDownloader",
            category: "ModelDownloader"
        )
    }

    /// Internal initializer for testing with custom dependencies
    internal init(
        fileManager: ModelFileManagerProtocol,
        downloader: HuggingFaceDownloaderProtocol,
        backgroundDownloadManager: BackgroundDownloadManaging,
        communityExplorer: CommunityModelsExplorerProtocol,
        logger: ModelDownloaderLogger = ModelDownloaderLogger(
            subsystem: "ModelDownloader",
            category: "ModelDownloader"
        )
    ) {
        self.fileManager = fileManager
        self.downloader = downloader
        self.backgroundDownloadManager = backgroundDownloadManager
        self.communityExplorer = communityExplorer
        self.logger = logger
    }

    /// Download a model using SendableModel configuration
    /// 
    /// This is the primary method for the SendableModel → Background Download → File URL workflow.
    /// The SendableModel's location field should contain the HuggingFace repository identifier.
    /// The backend from SendableModel determines the format to download.
    /// 
    /// **File System Structure:**
    /// Models are organized as: `{baseDir}/{backend}/{model.id}/`
    /// - MLX models: `~/Library/Application Support/ThinkAI/Models/mlx/{uuid}/`
    /// - GGUF models: `~/Library/Application Support/ThinkAI/Models/gguf/{uuid}/`
    /// - CoreML models: `~/Library/Application Support/ThinkAI/Models/coreml/{uuid}/`
    /// 
    /// **Usage Example:**
    /// ```swift
    /// let model: SendableModel = SendableModel(
    ///     id: UUID(),
    ///     ramNeeded: 8_000_000_000,
    ///     modelType: .language,
    ///     backend: .mlx,
    ///     location: "mlx-community/Llama-3.2-1B-Instruct-4bit"
    /// )
    /// 
    /// for try await event in downloader.downloadModel(sendableModel: model) {
    ///     switch event {
    ///     case .progress(let progress):
    ///         print("Progress: \(progress.percentage)%")
    ///     case .completed(let modelInfo):
    ///         let modelURL = await downloader.getModelLocation(for: model)
    ///         // Use modelURL with CoreML, LlamaCPP, or MLX
    ///     }
    /// }
    /// ```
    /// 
    /// - Parameter sendableModel: The SendableModel containing ID, backend, and HuggingFace 
    ///   repository location
    /// - Returns: AsyncThrowingStream that yields download progress and completion events
    public func downloadModel(
        sendableModel: SendableModel
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { [self] in
                await logger.info("Starting SendableModel download", metadata: [
                    "sendableModelId": sendableModel.id.uuidString,
                    "repositoryId": sendableModel.location,
                    "backend": sendableModel.backend.rawValue,
                    "modelType": sendableModel.modelType.rawValue
                ])

                // Set up cleanup
                continuation.onTermination = { @Sendable _ in
                    Task { [logger] in
                        await logger.debug("Download stream terminated", metadata: [
                            "sendableModelId": sendableModel.id.uuidString
                        ])
                    }
                }

                // Forward events from the internal downloader
                do {
                    for try await event in downloader.download(
                        modelId: sendableModel.location,
                        backend: sendableModel.backend,
                        customId: sendableModel.id
                    ) {
                        // Check for cancellation
                        try Task.checkCancellation()

                        continuation.yield(event)

                        // Log completion
                        if case .completed(let result) = event {
                            await logger.info("SendableModel download completed successfully", metadata: [
                                "sendableModelId": sendableModel.id.uuidString,
                                "repositoryId": sendableModel.location,
                                "backend": sendableModel.backend.rawValue,
                                "finalLocation": result.location.path
                            ])
                        }
                    }

                    continuation.finish()
                } catch {
                    await logger.error("SendableModel download failed", error: error, metadata: [
                        "sendableModelId": sendableModel.id.uuidString,
                        "repositoryId": sendableModel.location,
                        "backend": sendableModel.backend.rawValue
                    ])
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// List all downloaded models across all formats.
    ///
    /// Scans the models directory for all downloaded models and returns their metadata.
    /// This includes models downloaded in MLX, GGUF, and CoreML formats.
    ///
    /// Example:
    /// ```swift
    /// let models: Data = try await downloader.listDownloadedModels()
    /// for model in models  {
    ///     print("\(model.name): \(model.format) - \(model.totalSize) bytes")
    /// }
    /// ```
    ///
    /// - Returns: Array of `ModelInfo` objects representing all downloaded models
    /// - Throws: `FileManagerError` if unable to access the models directory
    public func listDownloadedModels() async throws -> [ModelInfo] {
        await logger.debug("Listing downloaded models")

        do {
            let models: [ModelInfo] = try await fileManager.listDownloadedModels()
            await logger.info("Listed downloaded models", metadata: ["count": models.count])
            return models
        } catch {
            await logger.error("Failed to list downloaded models", error: error)
            throw error
        }
    }

    /// Check if a model exists locally.
    ///
    /// Verifies whether a model with the given repository location has been downloaded to the local
    /// file system. This is useful for checking before attempting to load a model.
    ///
    /// Example:
    /// ```swift
    /// if await downloader.modelExists(model: "mlx-community/Llama-3.2-1B") {
    ///     // Model is ready to use
    ///     let url = await downloader.getModelLocation(for: "mlx-community/Llama-3.2-1B")
    /// } else {
    ///     // Need to download the model first
    ///     try await downloader.downloadModelSafely(model: "mlx-community/Llama-3.2-1B")
    /// }
    /// ```
    ///
    /// - Parameter model: Repository location of the model to check (e.g., "owner/model-name")
    /// - Returns: `true` if the model exists locally, `false` otherwise
    public func modelExists(model: ModelLocation) async -> Bool {
        await logger.debug("Checking if model exists", metadata: ["modelLocation": model])

        let exists: Bool = await fileManager.modelExists(repositoryId: model)
        await logger.debug("Model existence check result", metadata: [
            "modelLocation": model,
            "exists": exists
        ])
        return exists
    }

    /// Delete a downloaded model from local storage.
    ///
    /// Permanently removes all files associated with the specified model, including
    /// model weights, configuration files, and metadata. This action cannot be undone.
    ///
    /// Example:
    /// ```swift
    /// // Free up disk space by removing unused models
    /// try await downloader.deleteModel(model: "mlx-community/Llama-3.2-1B")
    /// ```
    ///
    /// - Parameter model: Repository location of the model to delete (e.g., "owner/model-name")
    /// - Throws: `FileManagerError.modelNotFound` if the model doesn't exist
    /// - Throws: `FileManagerError.deletionFailed` if unable to remove the model files
    public func deleteModel(model: ModelLocation) async throws {
        await logger.info("Deleting model", metadata: ["modelLocation": model])

        do {
            try await fileManager.deleteModel(repositoryId: model)
            await logger.info("Model deleted successfully", metadata: [
                "modelLocation": model
            ])
        } catch {
            await logger.error("Failed to delete model", error: error, metadata: [
                "modelLocation": model
            ])
            throw error
        }
    }

    /// Get the total size of a downloaded model.
    ///
    /// Calculates the combined size of all files associated with the model,
    /// including weights, configuration, and any additional files.
    ///
    /// Example:
    /// ```swift
    /// if let sizeBytes = await downloader.getModelSize(model: "mlx-community/Llama-3.2-1B") {
    ///      let sizeGB: Double = Double(sizeBytes) / 1_000_000_000
    ///     print("Model size: \(String(format: "%.2f", sizeGB)) GB")
    /// }
    /// ```
    ///
    /// - Parameter model: Repository location of the model (e.g., "owner/model-name")
    /// - Returns: Total size in bytes, or `nil` if the model doesn't exist
    public func getModelSize(model: ModelLocation) async -> Int64? {
        await logger.debug("Getting model size", metadata: ["modelLocation": model])

        let size: Int64? = await fileManager.getModelSize(repositoryId: model)
        if let size: Int64 {
            await logger.debug("Model size retrieved", metadata: [
                "modelLocation": model,
                "size": size
            ])
        } else {
            await logger.debug("Model not found for size check", metadata: [
                "modelLocation": model
            ])
        }
        return size
    }

    /// Check available disk space on the volume containing the models directory.
    ///
    /// Use this before downloading large models to ensure sufficient space.
    /// The returned value represents free space available to non-privileged processes.
    ///
    /// Example:
    /// ```swift
    /// if let availableBytes = await downloader.availableDiskSpace() {
    ///      let availableGB: Double = Double(availableBytes) / 1_000_000_000
    ///     if availableGB < 10 {
    ///         print("Warning: Only \(availableGB)GB available")
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: Available space in bytes, or `nil` if unable to determine
    public func availableDiskSpace() async -> Int64? {
        await logger.debug("Checking available disk space")

        let space: Int64? = await fileManager.availableDiskSpace()
        if let space: Int64 {
            await logger.debug("Available disk space", metadata: ["bytes": space])
        } else {
            await logger.warning("Unable to determine available disk space")
        }
        return space
    }

    /// Clean up incomplete downloads and temporary files.
    ///
    /// Removes temporary download files that are older than 24 hours, which likely
    /// represent failed or interrupted downloads. This helps reclaim disk space
    /// without affecting active downloads.
    ///
    /// Example:
    /// ```swift
    /// // Periodic cleanup in app lifecycle
    /// Task {
    ///     try await downloader.cleanupIncompleteDownloads()
    ///     print("Cleanup completed")
    /// }
    /// ```
    ///
    /// - Throws: `FileManagerError` if unable to access or remove temporary files
    public func cleanupIncompleteDownloads() async throws {
        await logger.info("Starting cleanup of incomplete downloads")

        do {
            try await fileManager.cleanupIncompleteDownloads()
            await logger.info("Cleanup of incomplete downloads completed")
        } catch {
            await logger.error("Failed to cleanup incomplete downloads", error: error)
            throw error
        }
    }

    /// Cancel an ongoing download.
    ///
    /// Immediately stops the download process for the specified model.
    /// Any partially downloaded files will be cleaned up automatically.
    ///
    /// Example:
    /// ```swift
    /// // User tapped cancel button
    /// await downloader.cancelDownload(for: "mlx-community/Llama-3.2-1B")
    /// ```
    ///
    /// - Parameter modelId: HuggingFace repository identifier (e.g., "owner/model-name")
    /// - Note: This method is safe to call even if no download is in progress
    public func cancelDownload(for modelId: String) async {
        await logger.info("Cancelling download", metadata: ["modelId": modelId])
        await downloader.cancelDownload(for: modelId)
        await logger.info("Download cancelled", metadata: ["modelId": modelId])
    }

    /// Pauses an active download for the specified model.
    /// The download can be resumed later from where it left off.
    ///
    /// Example:
    /// ```swift
    /// // User tapped pause button
    /// await downloader.pauseDownload(for: "mlx-community/Llama-3.2-1B")
    /// ```
    ///
    /// - Parameter model: Repository location of the model to pause (e.g., "owner/model-name")
    /// - Note: This method is safe to call even if no download is in progress
    public func pauseDownload(for model: ModelLocation) async {
        await logger.info("Pausing download", metadata: ["modelLocation": model])
        await downloader.pauseDownload(for: model)
        await logger.info("Download paused", metadata: ["modelLocation": model])
    }

    /// Resumes a paused download for the specified model.
    /// The download will continue from where it was paused.
    ///
    /// Example:
    /// ```swift
    /// // User tapped resume button
    /// await downloader.resumeDownload(for: "mlx-community/Llama-3.2-1B")
    /// ```
    ///
    /// - Parameter model: Repository location of the model to resume (e.g., "owner/model-name")
    /// - Note: This method is safe to call even if no download is paused
    public func resumeDownload(for model: ModelLocation) async {
        await logger.info("Resuming download", metadata: ["modelLocation": model])
        await downloader.resumeDownload(for: model)
        await logger.info("Download resumed", metadata: ["modelLocation": model])
    }

    // MARK: - Background Download Support

    /// Resume all persisted background downloads that were interrupted by app termination or system events.
    ///
    /// This method should be called during app launch to restore download state and continue any
    /// interrupted downloads. The system automatically persists background download state across
    /// app launches and device restarts.
    ///
    /// - Returns: Array of handles for resumed downloads that are still in progress
    /// - Note: Only downloads in pending, downloading, or paused states will be resumed
    public func resumeBackgroundDownloads() async throws -> [BackgroundDownloadHandle] {
        await logger.info("Resuming background downloads")
        try Task.checkCancellation()
        let handles: [BackgroundDownloadHandle] = await backgroundDownloadManager.resumeAllDownloads()

        await logger.info("Background downloads resumed", metadata: [
            "count": handles.count
        ])

        return handles
    }

    /// Handle background download completion events from the system.
    ///
    /// This method must be called from your app delegate's background download completion handler
    /// to properly handle downloads that completed while the app was backgrounded or terminated.
    /// Failing to call this method will prevent proper background download completion handling.
    ///
    /// Example usage in AppDelegate:
    /// ```swift
    /// func application(
    ///     _ application: UIApplication,
    ///     handleEventsForBackgroundURLSession identifier: String,
    ///     completionHandler: @escaping () -> Void
    /// ) {
    ///     ModelDownloader.shared.handleBackgroundDownloadCompletion(
    ///         identifier: identifier,
    ///         completionHandler: completionHandler
    ///     )
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - identifier: Background session identifier provided by the system
    ///   - completionHandler: System completion handler that must be called when processing is complete
    @preconcurrency
    public func handleBackgroundDownloadCompletion(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        Task {
            await logger.info("Handling background download completion", metadata: [
                "identifier": identifier
            ])

            await backgroundDownloadManager.handleBackgroundCompletion(
                identifier: identifier,
                completionHandler: completionHandler
            )
        }
    }

    /// Get status of all active background downloads.
    ///
    /// Returns detailed status information for all background downloads currently
    /// managed by the system, including progress, state, and error information.
    ///
    /// Example:
    /// ```swift
    /// let statuses = await downloader.backgroundDownloadStatus()
    /// for status in statuses  {
    ///     print("\(status.modelId): \(status.state) - \(status.progress)%")
    ///     if let error = status.error {
    ///         print("  Error: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: Array of `BackgroundDownloadStatus` objects for all active downloads
    public func backgroundDownloadStatus() async -> [BackgroundDownloadStatus] {
        let statuses: [BackgroundDownloadStatus] = backgroundDownloadManager.getActiveDownloads()

        await logger.debug("Retrieved background download statuses", metadata: [
            "count": statuses.count
        ])

        return statuses
    }

    /// Cancel a specific background download.
    ///
    /// Stops the specified background download and removes it from the download queue.
    /// The partial download will be cleaned up automatically.
    ///
    /// Example:
    /// ```swift
    /// // Cancel a specific download
    /// let handles = await downloader.backgroundDownloadStatus()
    /// if let handle = handles.first(where: { $0.modelId == "unwanted-model" }) {
    ///     await downloader.cancelBackgroundDownload(handle)
    /// }
    /// ```
    ///
    /// - Parameter handle: The `BackgroundDownloadHandle` obtained from `downloadModelInBackground`
    ///                     or `backgroundDownloadStatus`
    public func cancelBackgroundDownload(_ handle: BackgroundDownloadHandle) async {
        await logger.info("Cancelling background download", metadata: [
            "downloadId": handle.id.uuidString,
            "modelId": handle.modelId
        ])

        await backgroundDownloadManager.cancelDownload(id: handle.id)

        await logger.info("Background download cancelled", metadata: [
            "downloadId": handle.id.uuidString
        ])
    }

    /// Request notification permission for background download notifications.
    ///
    /// Background downloads can show notifications when downloads complete, fail, or require user
    /// attention. This method should be called early in your app's lifecycle to ensure users
    /// receive download completion notifications.
    ///
    /// Example:
    /// ```swift
    /// // In app initialization
    /// Task {
    ///     let granted = await ModelDownloader.shared.requestNotificationPermission()
    ///     if !granted {
    ///         print("User declined notifications - downloads will complete silently")
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: `true` if notification permission was granted, `false` otherwise
    /// - Note: This is required for background download completion notifications to appear
    public func requestNotificationPermission() async -> Bool {
        await logger.debug("Requesting notification permission for background downloads")

        let notificationManager: DownloadNotificationManager = DownloadNotificationManager()
        let granted: Bool = await notificationManager.requestNotificationPermission()

        await logger.info("Notification permission result", metadata: [
            "granted": granted
        ])

        return granted
    }

    // MARK: - SendableModel File Location Methods

    /// Get the file system location for a downloaded model.
    ///
    /// This method is essential for the complete workflow: after a model is downloaded,
    /// use this method to get the file URL needed for model execution with CoreML, LlamaCPP, or MLX.
    ///
    /// **Returns the directory containing the model files**, not individual files.
    /// For MLX and GGUF models, look for `.safetensors` or `.gguf` files within this directory.
    /// For CoreML models, look for `.mlmodel` or `.mlpackage` files.
    ///
    /// Example:
    /// ```swift
    /// // After download completes
    /// if let modelURL = await downloader.getModelLocation(for: "mlx-community/Llama-3.2-1B") {
    ///     // Pass to inference engine
    ///     let mlxModel = try MLXModel(modelURL: modelURL)
    ///     // or
    ///     let llamaModel = try LlamaCPPModel(modelPath: modelURL.path)
    /// }
    /// ```
    ///
    /// - Parameter model: The repository location of the model (e.g., "owner/model-name")
    /// - Returns: URL to the model directory, or `nil` if not found
    public func getModelLocation(for model: ModelLocation) async -> URL? {
        await logger.debug("Getting model location", metadata: [
            "modelLocation": model
        ])

        // Log the entire model repository state at the start
        // Note: We can't access baseDirectory from the protocol, so we'll skip the repository overview

        // Try all backends to find where the model is stored
        for backend: SendableModel.Backend in SendableModel.Backend.localCases {
            let location: URL = fileManager.modelDirectory(for: model, backend: backend)
            if directoryExists(location) {
                await logger.debug("Found model at repository-based location", metadata: [
                    "modelLocation": model,
                    "backend": backend.rawValue,
                    "location": location.path
                ])

                // For GGUF models, we need to return the path to the actual .gguf file
                // For other backends (MLX, CoreML), return the directory
                if backend == .gguf {
                    // Find the .gguf file in the directory
                    let fileURLs: [URL] = (try? FileManager.default.contentsOfDirectory(
                        at: location,
                        includingPropertiesForKeys: nil,
                        options: .skipsHiddenFiles
                    )) ?? []

                    let ggufFile: URL? = fileURLs.first { url in
                        url.pathExtension.lowercased() == "gguf"
                    }

                    if let ggufFile {
                        await logger.info("Found GGUF file", metadata: [
                            "modelLocation": model,
                            "backend": backend.rawValue,
                            "path": ggufFile.path
                        ])
                        return ggufFile
                    }
                    await logger.error("GGUF directory exists but no .gguf file found", metadata: [
                        "modelLocation": model,
                        "directory": location.path,
                        "files": fileURLs.map(\.lastPathComponent).joined(separator: ", ")
                    ])
                    return nil
                }
                await logger.info("Found model at location", metadata: [
                    "modelLocation": model,
                    "backend": backend.rawValue,
                    "path": location.path
                ])
                return location
            }
        }

        await logger.warning("Model not found", metadata: [
            "modelLocation": model
        ])
        return nil
    }

    /// Get the specific file URL for a model and filename.
    ///
    /// Use this when you need to access a specific file within the model directory.
    ///
    /// **Common file patterns:**
    /// - MLX models: `"model.safetensors"`, `"config.json"`, `"tokenizer.json"`
    /// - GGUF models: `"model.gguf"`, `"config.json"`
    /// - CoreML models: `"model.mlmodel"`, `"model.mlpackage"`
    ///
    /// Example:
    /// ```swift
    /// // Access specific configuration file
    /// if let configURL = await downloader.getModelFileURL(
    ///     for: "mlx-community/Llama-3.2-1B", 
    ///     fileName: "config.json"
    /// ) {
    ///     let config = try Data(contentsOf: configURL)
    ///     // Parse configuration...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - model: The repository location of the model (e.g., "owner/model-name")
    ///   - fileName: Specific file name within the model directory
    /// - Returns: URL to the specific file, or `nil` if not found
    public func getModelFileURL(for model: ModelLocation, fileName: String) async -> URL? {
        guard let modelLocation = await getModelLocation(for: model) else {
            return nil
        }

        let fileURL: URL = modelLocation.appendingPathComponent(fileName)
        let exists: Bool = FileManager.default.fileExists(atPath: fileURL.path)

        await logger.debug("Checking model file", metadata: [
            "modelLocation": model,
            "fileName": fileName,
            "exists": exists,
            "fullPath": fileURL.path
        ])

        return exists ? fileURL : nil
    }

    /// Get all files in the model directory for a model.
    ///
    /// Useful for discovering what files are available in a downloaded model directory.
    /// Files are returned as absolute URLs that can be used directly for file operations.
    ///
    /// Example:
    /// ```swift
    /// let files = await downloader.getModelFiles(for: "mlx-community/Llama-3.2-1B")
    /// for file in files  {
    ///     print("\(file.lastPathComponent): \(file.fileSizeString ?? "unknown")")
    /// }
    /// 
    /// // Find specific file types
    /// let safetensors: [String] = files.filter { $0.pathExtension == "safetensors" }
    /// let configs: [String] = files.filter { $0.lastPathComponent.contains("config") }
    /// ```
    ///
    /// - Parameter model: The repository location of the model to inspect (e.g., "owner/model-name")
    /// - Returns: Array of file URLs in the model directory, or empty array if model not found
    public func getModelFiles(for model: ModelLocation) async -> [URL] {
        guard let modelLocation = await getModelLocation(for: model) else {
            await logger.warning("Cannot list files - model location not found", metadata: [
                "modelLocation": model
            ])
            return []
        }

        do {
            let contents: [URL] = try FileManager.default.contentsOfDirectory(
                at: modelLocation,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )

            let files: [URL] = try contents.filter { url in
                let resourceValues: URLResourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
                return resourceValues.isRegularFile == true
            }

            await logger.debug("Listed model files", metadata: [
                "modelLocation": model,
                "fileCount": files.count,
                "files": files.map(\.lastPathComponent).joined(separator: ", ")
            ])

            return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            await logger.error("Failed to list model files", error: error, metadata: [
                "modelLocation": model,
                "modelLocationPath": modelLocation.path
            ])
            return []
        }
    }

    /// Get ModelInfo for a model if it has been downloaded.
    ///
    /// This retrieves the download metadata for a model by its repository location.
    /// Returns nil if the model hasn't been downloaded yet.
    ///
    /// Example:
    /// ```swift
    /// // Check download details for a model
    /// if let info = await downloader.getModelInfo(for: "mlx-community/Llama-3.2-1B") {
    ///     print("Model: \(info.name)")
    ///     print("Backend: \(info.backend)")
    ///     print("Size: \(info.totalSize) bytes")
    ///     print("Downloaded: \(info.downloadDate)")
    /// } else {
    ///     print("Model not downloaded yet")
    /// }
    /// ```
    ///
    /// - Parameter model: The repository location of the model (e.g., "owner/model-name")
    /// - Returns: Corresponding `ModelInfo` if model is downloaded, `nil` otherwise
    public func getModelInfo(for model: ModelLocation) async -> ModelInfo? {
        await logger.debug("Getting ModelInfo for model", metadata: [
            "modelLocation": model
        ])

        do {
            let allModels: [ModelInfo] = try await fileManager.listDownloadedModels()
            let matchingModel: ModelInfo? = allModels.first { modelInfo in
                // Match by repository ID stored in metadata
                if let repositoryId = modelInfo.metadata["repositoryId"] {
                    return repositoryId == model
                }
                // Fallback: try matching by name
                return modelInfo.name == model
            }

            if let foundModel: ModelInfo = matchingModel {
                await logger.debug("Found matching ModelInfo", metadata: [
                    "modelLocation": model,
                    "backend": foundModel.backend.rawValue,
                    "size": foundModel.totalSize
                ])
            } else {
                await logger.debug("No matching ModelInfo found", metadata: [
                    "modelLocation": model
                ])
            }

            return matchingModel
        } catch {
            await logger.error("Failed to get ModelInfo for model", error: error, metadata: [
                "modelLocation": model
            ])
            return nil
        }
    }

    // MARK: - Background Download with SendableModel

    /// Download a model in the background with system-managed downloads.
    ///
    /// This method implements the complete workflow:
    /// 1. Repository location provides the HuggingFace model ID
    /// 2. Background download continues even when app is suspended
    /// 3. System notifications alert user when download completes
    /// 4. Use `getModelLocation(for:)` to get file URL for model execution
    ///
    /// **Recommended Format Selection:**
    /// - `.mlx` for Apple Silicon devices with MLX inference
    /// - `.gguf` for cross-platform LlamaCPP inference
    /// - `.coreml` for CoreML inference (iOS/macOS only)
    ///
    /// Example:
    /// ```swift
    /// // Start background download
    /// let handle: Data = try await downloader.downloadModelInBackground(
    ///     sendableModel: "mlx-community/Llama-3.2-1B",
    ///     options: BackgroundDownloadOptions(
    ///         enableCellular: false,
    ///         isDiscretionary: true
    ///     )
    /// )
    /// 
    /// // Monitor progress when app is active
    /// for try await event in handle.events {
    ///     switch event {
    ///     case .progress(let progress):
    ///         updateUI(progress)
    ///     case .completed:
    ///         print("Download completed!")
    ///     case .failed(let error):
    ///         handleError(error)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - sendableModel: Repository location of the model (e.g., "owner/model-name")
    ///   - options: Background download configuration options
    /// - Returns: AsyncThrowingStream that yields `BackgroundDownloadEvent` updates
    /// - Throws: `ModelDownloadError` if unable to start the download
    public func downloadModelInBackground(
        sendableModel: ModelLocation,
        options: BackgroundDownloadOptions = BackgroundDownloadOptions()
    ) -> AsyncThrowingStream<BackgroundDownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { [self] in
                await logger.info("Starting background model download", metadata: [
                    "modelLocation": sendableModel,
                    "enableCellular": options.enableCellular,
                    "isDiscretionary": options.isDiscretionary
                ])

                // Set up cleanup
                continuation.onTermination = { @Sendable _ in
                    Task { [logger] in
                        await logger.debug("Background download stream terminated", metadata: [
                            "modelLocation": sendableModel
                        ])
                    }
                }

                do {
                    // Get recommended backend for the model
                    let recommendedBackend: SendableModel.Backend = await getRecommendedBackend(for: sendableModel)

                    // Get model information and files to download using repository location
                    let files: [FileDownloadInfo] = try await downloader.getModelFiles(
                        modelId: sendableModel,
                        backend: recommendedBackend
                    )

                    // Convert to background download format
                    let backgroundFiles: [BackgroundFileDownload] = files.map { file in
                        BackgroundFileDownload(
                            url: file.url,
                            localPath: file.localPath,
                            size: file.size,
                            relativePath: file.path
                        )
                    }

                    // Log the files we're about to download
                    await logger.info("=== BACKGROUND DOWNLOAD FILES ===", metadata: [
                        "modelLocation": sendableModel,
                        "fileCount": backgroundFiles.count,
                        "files": backgroundFiles.map { "\($0.relativePath) (\($0.size) bytes)" }.joined(separator: ", ")
                    ])

                    // Create download directory based on repository ID
                    let safeDirName: String = sendableModel.safeDirectoryName
                    let downloadDir: URL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("ThinkAI/Downloads", isDirectory: true)
                        .appendingPathComponent(safeDirName, isDirectory: true)

                    // Update file paths to use repository-based directory
                    let updatedFiles: [BackgroundFileDownload] = backgroundFiles.map { file in
                        BackgroundFileDownload(
                            url: file.url,
                            localPath: downloadDir.appendingPathComponent(file.relativePath),
                            size: file.size,
                            relativePath: file.relativePath
                        )
                    }

                    await logger.info("Updated file paths for repository-based download", metadata: [
                        "downloadDir": downloadDir.path,
                        "firstFile": updatedFiles.first?.localPath.path ?? "none"
                    ])

                    // Start download with progress callback
                    // Note: We use repository ID as the modelId for consistency
                    let handle: BackgroundDownloadHandle = try backgroundDownloadManager.downloadModel(
                        modelId: sendableModel,
                        backend: recommendedBackend,
                        files: updatedFiles,
                        options: options
                    ) { progress in
                            // Log progress updates
                            Task { [logger] in
                                await logger.debug("Background download progress", metadata: [
                                    "modelLocation": sendableModel,
                                    "bytesDownloaded": progress.bytesDownloaded,
                                    "totalBytes": progress.totalBytes,
                                    "filesCompleted": progress.filesCompleted,
                                    "totalFiles": progress.totalFiles,
                                    "currentFile": progress.currentFileName ?? "none"
                                ])
                            }

                            // Emit progress events
                            continuation.yield(.progress(progress))

                            // Check if download is complete
                            if progress.filesCompleted >= progress.totalFiles,
                               progress.bytesDownloaded >= progress.totalBytes {
                                // Get model info for completion event
                                Task { [self] in
                                    await logger.info("=== DOWNLOAD APPEARS COMPLETE ===", metadata: [
                                        "modelLocation": sendableModel,
                                        "filesCompleted": progress.filesCompleted,
                                        "totalFiles": progress.totalFiles
                                    ])

                                    do {
                                        // Finalize the download - this will move files to final location
                                        // and handle CoreML flattening
                                        let finalizedModelInfo: ModelInfo = try await fileManager.finalizeDownload(
                                            repositoryId: sendableModel,
                                            name: sendableModel,
                                            backend: recommendedBackend,
                                            from: downloadDir,
                                            totalSize: progress.totalBytes
                                        )

                                        await logger.info("Download finalized successfully", metadata: [
                                            "modelLocation": sendableModel,
                                            "modelId": finalizedModelInfo.id.uuidString,
                                            "finalLocation": finalizedModelInfo.location.path
                                        ])

                                        continuation.yield(.completed(finalizedModelInfo))
                                        continuation.finish()
                                    } catch {
                                        await logger.error("Failed to finalize download", error: error, metadata: [
                                            "modelLocation": sendableModel
                                        ])
                                        continuation.finish(throwing: error)
                                    }
                                }
                            }
                    }

                    await logger.info("Background model download initiated", metadata: [
                        "modelLocation": sendableModel,
                        "downloadId": handle.id.uuidString,
                        "fileCount": backgroundFiles.count
                    ])

                    // Emit the handle first
                    continuation.yield(.handle(handle))

                    // Set up termination cleanup
                    continuation.onTermination = { @Sendable termination in
                        switch termination {
                        case .cancelled:
                            Task { [logger] in
                                await logger.debug("Background download cancelled", metadata: [
                                    "modelLocation": sendableModel,
                                    "downloadId": handle.id.uuidString
                                ])
                                await handle.cancel()
                            }

                        default:
                            break
                        }
                    }
                } catch {
                    await logger.error("Failed to start background model download", error: error, metadata: [
                        "modelLocation": sendableModel
                    ])
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Validation and Error Handling

    /// Validate model before downloading.
    ///
    /// Performs comprehensive validation to catch common issues early:
    /// - Repository ID format validation
    /// - Duplicate download detection
    /// - Available disk space check
    ///
    /// Example:
    /// ```swift
    /// // Validate before downloading
    /// do {
    ///     let validation: Data = try await downloader.validateModel("mlx-community/Llama-3.2-1B", backend: .mlx)
    ///     if !validation.warnings.isEmpty {
    ///         print("Warnings: \(validation.warnings)")
    ///     }
    ///     // Proceed with download...
    /// } catch ModelDownloadError.insufficientMemory(let required, let available) {
    ///     print("Need \(required) bytes, only \(available) available")
    /// } catch {
    ///     print("Validation failed: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - model: Repository location to validate (e.g., "owner/model-name")
    ///   - backend: Intended download backend
    /// - Returns: `ValidationResult` containing any warnings
    /// - Throws: `ModelDownloadError` for blocking issues that prevent download
    public func validateModel(
        _ model: ModelLocation,
        backend: SendableModel.Backend
    ) async throws -> ValidationResult {
        await logger.debug("Validating model", metadata: [
            "modelLocation": model,
            "backend": backend.rawValue
        ])

        // Validate repository ID format
        let repoComponents: [Substring] = model.split(separator: "/")
        if repoComponents.count != 2 || repoComponents.contains(where: \.isEmpty) {
            await logger.error("Invalid repository ID format", metadata: [
                "modelLocation": model
            ])
            throw ModelDownloadError.invalidRepositoryIdentifier(model)
        }

        // Check if model is already downloaded
        let exists: Bool = await fileManager.modelExists(repositoryId: model)
        if exists {
            let identityService: ModelIdentityService = ModelIdentityService()
            let modelId: UUID = await identityService.generateModelId(for: model)
            await logger.warning("Model already downloaded", metadata: [
                "modelLocation": model,
                "modelId": modelId.uuidString
            ])
            throw ModelDownloadError.modelAlreadyDownloaded(modelId)
        }

        // Return basic validation result (no complex model type compatibility needed)
        let validationResult: ValidationResult = ValidationResult(isValid: true, warnings: [])

        await logger.info("Model validation completed", metadata: [
            "modelLocation": model,
            "validationPassed": true,
            "warningCount": validationResult.warnings.count
        ])

        return validationResult
    }

    /// Get recommended backend for a model
    /// 
    /// Provides intelligent backend selection based on repository hints and system capabilities.
    /// 
    /// - Parameter model: Repository location to analyze (e.g., "owner/model-name")
    /// - Returns: Recommended Backend
    public func getRecommendedBackend(for model: ModelLocation) async -> SendableModel.Backend {
        if let detectedBackends = await detectAvailableBackends(for: model),
           let preferred = choosePreferredBackend(from: detectedBackends) {
            await logger.debug("Backend recommendation from detection", metadata: [
                "modelLocation": model,
                "detectedBackends": detectedBackends.map(\.rawValue).joined(separator: ", "),
                "recommendedBackend": preferred.rawValue
            ])
            return preferred
        }

        // Fallback heuristics based on repository name patterns
        let modelLower: String = model.lowercased()

        let recommendedBackend: SendableModel.Backend
        if modelLower.contains("mlx") {
            recommendedBackend = .mlx
        } else if modelLower.contains("gguf") || modelLower.contains("llamacpp") {
            recommendedBackend = .gguf
        } else if modelLower.contains("coreml") {
            recommendedBackend = .coreml
        } else {
            // Default to MLX for Apple Silicon
            recommendedBackend = .mlx
        }

        await logger.debug("Backend recommendation", metadata: [
            "modelLocation": model,
            "recommendedBackend": recommendedBackend.rawValue
        ])

        return recommendedBackend
    }

    private func detectAvailableBackends(for model: ModelLocation) async -> [SendableModel.Backend]? {
        do {
            let discovered: DiscoveredModel = try await communityExplorer.discoverModel(model)
            return await MainActor.run {
                discovered.detectedBackends
            }
        } catch {
            await logger.warning("Backend detection failed", metadata: [
                "modelLocation": model,
                "error": error.localizedDescription
            ])
            return nil
        }
    }

    private func choosePreferredBackend(
        from backends: [SendableModel.Backend]
    ) -> SendableModel.Backend? {
        let preferredOrder: [SendableModel.Backend] = [.mlx, .gguf, .coreml]
        return preferredOrder.first { backends.contains($0) }
    }

    /// Validate and download a model with automatic backend selection
    /// 
    /// This method combines validation, backend recommendation, and download into one operation:
    /// 1. Validates the model repository location
    /// 2. Selects optimal backend if not specified
    /// 3. Downloads with comprehensive error handling
    /// 
    /// - Parameters:
    ///   - model: Repository location of the model to download (e.g., "owner/model-name")
    ///   - backend: Optional backend (auto-detected if nil)
    /// - Returns: AsyncThrowingStream that yields download progress and completion events
    public func downloadModelSafely(
        model: ModelLocation,
        backend: SendableModel.Backend? = nil
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { [self] in
                await logger.info("Starting safe model download", metadata: [
                    "modelLocation": model,
                    "specifiedBackend": backend?.rawValue ?? "auto-detect"
                ])

                // Determine backend
                let selectedBackend: SendableModel.Backend
                if let providedBackend: SendableModel.Backend = backend {
                    selectedBackend = providedBackend
                } else {
                    selectedBackend = await getRecommendedBackend(for: model)
                }

                // Validate before download
                do {
                    let validationResult: ValidationResult = try await validateModel(model, backend: selectedBackend)

                    // Log validation warnings
                    if !validationResult.warnings.isEmpty {
                        await logger.warning("Proceeding with warnings", metadata: [
                            "modelLocation": model,
                            "warnings": validationResult.warnings.joined(separator: "; ")
                        ])
                    }

                    // Set up cleanup
                    continuation.onTermination = { @Sendable _ in
                        Task { [logger] in
                            await logger.debug("Safe download stream terminated", metadata: [
                                "modelLocation": model
                            ])
                        }
                    }

                    // Generate a UUID for this download using our identity service
                    let identityService: ModelIdentityService = ModelIdentityService()
                    let downloadId: UUID = await identityService.generateModelId(for: model)

                    // Forward events from the internal downloader with metadata enhancement
                    for try await event in downloader.download(
                        modelId: model,
                        backend: selectedBackend,
                        customId: downloadId
                    ) {
                        // Check for cancellation
                        try Task.checkCancellation()

                        switch event {
                        case .progress(let progress):
                            continuation.yield(.progress(progress))

                        case .completed(let result):
                            // Enhance metadata with repository location
                            var enhancedMetadata: [String: String] = result.metadata
                            enhancedMetadata["repositoryId"] = model
                            enhancedMetadata["source"] = "huggingface"
                            enhancedMetadata["downloadType"] = "repository-based"

                            let enhancedResult: ModelInfo = ModelInfo(
                                id: result.id,
                                name: result.name,
                                backend: result.backend,
                                location: result.location,
                                totalSize: result.totalSize,
                                downloadDate: result.downloadDate,
                                metadata: enhancedMetadata
                            )

                            await logger.info("Safe model download completed", metadata: [
                                "modelLocation": model,
                                "finalBackend": selectedBackend.rawValue,
                                "finalSize": result.totalSize
                            ])

                            continuation.yield(.completed(enhancedResult))
                        }
                    }

                    continuation.finish()
                } catch {
                    await logger.error("Safe model download failed", error: error, metadata: [
                        "modelLocation": model,
                        "backend": selectedBackend.rawValue
                    ])

                    // Convert to user-friendly error if possible
                    if let hfError: HuggingFaceError = error as? HuggingFaceError {
                        switch hfError {
                        case .repositoryNotFound, .modelNotFound:
                            continuation.finish(throwing: ModelDownloadError.repositoryNotFound(model))

                        case .insufficientDiskSpace, .diskSpaceInsufficient:
                            continuation.finish(throwing: ModelDownloadError.insufficientMemory(
                                required: 0, // We don't have RAM requirements from just the location
                                available: UInt64(await availableDiskSpace() ?? 0)
                            ))

                        default:
                            continuation.finish(throwing: error)
                        }
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists: Bool = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
