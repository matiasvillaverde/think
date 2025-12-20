import Abstractions
import Foundation
import os

/// Errors specific to background downloads
public enum BackgroundDownloadError: Error, LocalizedError {
    case noFilesToDownload
    case downloadNotFound
    case invalidConfiguration

    public var errorDescription: String? {
        switch self {
        case .noFilesToDownload:
            return "No files specified for download"

        case .downloadNotFound:
            return "Download not found"

        case .invalidConfiguration:
            return "Invalid download configuration"
        }
    }
}

/// Information stored in task description for state restoration
private struct TaskDescriptionInfo: Codable {
    let downloadId: String
    let filePath: String
}

/// Manages background downloads using traditional class-based approach
/// This is designed to work seamlessly with URLSession's delegate pattern
public final class BackgroundDownloadManager: @unchecked Sendable {
    /// Shared instance for convenient access
    public static let shared: BackgroundDownloadManager = BackgroundDownloadManager()

    // MARK: - Properties

    private let sessionIdentifier: String = "com.think.modeldownloader.background"
    private let logger: Logger = Logger(
        subsystem: "com.think.modeldownloader",
        category: "BackgroundDownloadManager"
    )
    private let backgroundSession: URLSession
    private let delegate: BackgroundDownloadManagerDelegate // swiftlint:disable:this weak_delegate
    internal let stateManager: DownloadStateManager

    // Thread-safe state container
    internal let state: StateContainer = StateContainer()

    // Background completion handlers (protected by queue)
    private let completionHandlerQueue: DispatchQueue = DispatchQueue(label: "com.think.modeldownloader.handlers")
    private var backgroundCompletionHandlers: [String: @Sendable () -> Void] = [:]

    private init() {
        #if os(iOS) || os(visionOS)
        // Use background configuration on iOS and visionOS for true background downloads
        let config: URLSessionConfiguration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        #else
        // Use default configuration on macOS to avoid background transfer service issues
        // Background URLSession has limited benefits on macOS and can cause -996 errors
        let config: URLSessionConfiguration = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        // No timeouts - some models can be 100GB+
        #endif

        // Create state manager
        self.stateManager = DownloadStateManager()

        // Create delegate with notification manager
        // In test environments, don't create a real notification manager
        let notificationManager: DownloadNotificationManager?
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Running in test environment - don't initialize notification manager
            notificationManager = nil
        } else {
            notificationManager = DownloadNotificationManager()
        }
        self.delegate = BackgroundDownloadManagerDelegate(
            notificationManager: notificationManager
        )

        // Create session with delegate
        self.backgroundSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        // Set the manager reference on the delegate
        self.delegate.setManager(self)

        // Restore persisted downloads on initialization
        Task {
            await restorePersistedDownloads()
            await restoreTaskMappings()
        }
    }

    deinit {
        // Cancel all active downloads
        backgroundSession.invalidateAndCancel()
    }

    // MARK: - Public API

    /// Start downloading a model with multiple files
    @preconcurrency
    public func downloadModel(
        modelId: String,
        backend: SendableModel.Backend,
        files: [BackgroundFileDownload],
        options: BackgroundDownloadOptions = BackgroundDownloadOptions(),
        progressCallback: (@Sendable (DownloadProgress) -> Void)? = nil
    ) throws -> BackgroundDownloadHandle {
        guard !files.isEmpty else {
            throw BackgroundDownloadError.noFilesToDownload
        }

        logger.info("Starting background download for \(modelId) with \(files.count) files")

        let downloadId: UUID = UUID()
        let totalBytes: Int64 = files.reduce(0) { $0 + $1.size }

        // Create persisted download record
        let persistedDownload: PersistedDownload = PersistedDownload(
            id: downloadId,
            modelId: modelId,
            backend: backend,
            sessionIdentifier: sessionIdentifier,
            options: options,
            expectedFiles: files.map(\.relativePath),
            fileDownloads: files,
            totalBytes: totalBytes,
            state: DownloadState.pending
        )

        // Store with thread safety
        state.setDownload(persistedDownload, for: downloadId)
        if let progressCallback {
            state.setProgressCallback(progressCallback, for: downloadId)
        }

        // Persist to storage
        Task {
            await stateManager.persistDownload(persistedDownload)
        }

        // Start downloading first file
        if let firstFile = files.first {
            logger.info("Starting download of first file: \(firstFile.relativePath)")

            var request: URLRequest = URLRequest(url: firstFile.url)
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

            let task: URLSessionDownloadTask = backgroundSession.downloadTask(with: request)

            // Store task info in taskDescription for state restoration
            let taskInfo: TaskDescriptionInfo = TaskDescriptionInfo(
                downloadId: downloadId.uuidString,
                filePath: firstFile.relativePath
            )
            if let taskData = try? JSONEncoder().encode(taskInfo),
               let taskDescription: String = String(data: taskData, encoding: .utf8) {
                task.taskDescription = taskDescription
            }

            // Store mappings
            state.setTaskMapping(downloadId: downloadId, file: firstFile, for: task.taskIdentifier)

            task.resume()

            logger.info("Download task started with ID: \(task.taskIdentifier)")
        }

        return BackgroundDownloadHandle(
            id: downloadId,
            modelId: modelId,
            backend: backend,
            sessionIdentifier: sessionIdentifier
        )
    }

    /// Cancel a download
    public func cancelDownload(id: UUID) async {
        logger.info("Cancelling download: \(id)")

        if let download = state.getDownload(for: id) {
            // Find and cancel the task
            await withCheckedContinuation { continuation in
                backgroundSession.getAllTasks { [weak self] tasks in
                    guard let self else {
                        continuation.resume()
                        return
                    }
                    for task in tasks where state.getDownloadId(for: task.taskIdentifier) == id {
                        task.cancel()
                    }
                    continuation.resume()
                }
            }

            // Update state
            let cancelledDownload: PersistedDownload = download.updatingProgress(
                bytesDownloaded: download.bytesDownloaded,
                state: .cancelled
            )
            state.setDownload(cancelledDownload, for: id)

            // Update persisted state
            await stateManager.persistDownload(cancelledDownload)
        }
    }

    /// Handle background app events completion
    @preconcurrency
    public func handleBackgroundCompletion(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) async {
        logger.info("Handling background completion for identifier: \(identifier)")

        if identifier == sessionIdentifier {
            await withCheckedContinuation { continuation in
                completionHandlerQueue.async { [weak self] in
                    self?.backgroundCompletionHandlers[identifier] = completionHandler
                    continuation.resume()
                }
            }
        } else {
            // Not our session, call completion immediately
            completionHandler()
        }
    }

    /// Call background completion handler if we have one
    internal func callBackgroundCompletionHandler(for identifier: String) {
        completionHandlerQueue.async { [weak self] in
            if let handler = self?.backgroundCompletionHandlers.removeValue(forKey: identifier) {
                handler()
            }
        }
    }

    /// Get current status of all background downloads
    public func getActiveDownloads() -> [BackgroundDownloadStatus] {
        var statuses: [BackgroundDownloadStatus] = []

        let downloads: [UUID: PersistedDownload] = state.getAllActiveDownloads()
        for (_, download) in downloads {
            let progress: Double = download.totalBytes > 0
                ? Double(download.bytesDownloaded) / Double(download.totalBytes)
                : 0.0

            let status: BackgroundDownloadStatus = BackgroundDownloadStatus(
                handle: download.toHandle(),
                state: download.state,
                progress: progress,
                error: nil, // Would need to track errors separately
                estimatedTimeRemaining: nil // Could calculate based on download speed
            )

            statuses.append(status)
        }

        return statuses
    }

    /// Get progress for a specific download
    public func getDownloadProgress(id: UUID) -> DownloadProgress? {
        guard let download = state.getDownload(for: id) else {
            return nil
        }

        return DownloadProgress(
            bytesDownloaded: download.bytesDownloaded,
            totalBytes: download.totalBytes,
            filesCompleted: download.completedFiles.count,
            totalFiles: download.expectedFiles.count,
            currentFileName: download.state == .downloading ? download.expectedFiles.last : nil
        )
    }

    // MARK: - State Restoration

    /// Restore task mappings from existing URLSession tasks
    private func restoreTaskMappings() async {
        logger.info("Restoring task mappings from existing URLSession tasks")

        await withCheckedContinuation { continuation in
            backgroundSession.getAllTasks { [weak self] tasks in
                guard let self else {
                    continuation.resume()
                    return
                }

                for task in tasks {
                    guard let taskDescription = task.taskDescription,
                          let taskData = taskDescription.data(using: .utf8),
                          let taskInfo = try? JSONDecoder().decode(TaskDescriptionInfo.self, from: taskData),
                          let downloadId: UUID = UUID(uuidString: taskInfo.downloadId) else {
                        continue
                    }

                    // Find the download and file info
                    if let download = state.getDownload(for: downloadId),
                       let file = download.fileDownloads.first(where: { $0.relativePath == taskInfo.filePath }) {
                        state.setTaskMapping(downloadId: downloadId, file: file, for: task.taskIdentifier)
                        logger.info(
                            "Restored task mapping for task \(task.taskIdentifier), file: \(taskInfo.filePath)"
                        )
                    }
                }

                continuation.resume()
            }
        }

        logger.info("Task mapping restoration complete")
    }

    /// Restore persisted downloads from storage
    private func restorePersistedDownloads() async {
        logger.info("Restoring persisted downloads")

        let persistedDownloads: [PersistedDownload] = await stateManager.getAllPersistedDownloads()

        for download in persistedDownloads {
            // Skip completed or failed downloads
            guard download.state == .pending || download.state == .downloading else {
                continue
            }

            // Restore to in-memory state
            state.setDownload(download, for: download.id)

            logger.info("Restored download: \(download.id) for model: \(download.modelId)")
        }

        logger.info("Restored \(persistedDownloads.count) downloads")
    }

    /// Resume persisted downloads
    public func resumeAllDownloads() async -> [BackgroundDownloadHandle] {
        logger.info("Resuming all persisted downloads")

        // Clean up stale downloads first
        await stateManager.cleanupStaleDownloads()

        let persistedDownloads: [PersistedDownload] = await stateManager.getAllPersistedDownloads()
        var handles: [BackgroundDownloadHandle] = []

        for download in persistedDownloads {
            // Skip completed or failed downloads
            guard download.state == .pending || download.state == .downloading else {
                continue
            }

            // Resume download by starting the next file
            if download.completedFiles.count < download.expectedFiles.count {
                // Find next file to download
                for (index, expectedFile) in download.expectedFiles.enumerated()
                where !download.completedFiles.contains(expectedFile) {
                    if index < download.fileDownloads.count {
                        let nextFile: BackgroundFileDownload = download.fileDownloads[index]

                        var request: URLRequest = URLRequest(url: nextFile.url)
                        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

                        let task: URLSessionDownloadTask = backgroundSession.downloadTask(with: request)

                        // Store task info in taskDescription for state restoration
                        let taskInfo: TaskDescriptionInfo = TaskDescriptionInfo(
                            downloadId: download.id.uuidString,
                            filePath: nextFile.relativePath
                        )
                        if let taskData = try? JSONEncoder().encode(taskInfo),
                           let taskDescription: String = String(data: taskData, encoding: .utf8) {
                            task.taskDescription = taskDescription
                        }

                        // Store mappings
                        state.setTaskMapping(downloadId: download.id, file: nextFile, for: task.taskIdentifier)

                        task.resume()

                        logger.info("Resumed download task for file: \(nextFile.relativePath)")
                    }
                    break
                }
            }

            let handle: BackgroundDownloadHandle = BackgroundDownloadHandle(
                id: download.id,
                modelId: download.modelId,
                backend: download.backend,
                sessionIdentifier: download.sessionIdentifier
            )
            handles.append(handle)
        }

        logger.info("Resumed \(handles.count) downloads")
        return handles
    }

    // MARK: - Helper Methods

    /// Check if a file is a ZIP archive based on its extension
    internal static func isZipFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "zip"
    }

    // MARK: - Private Helpers

    internal func startNextFileDownload(downloadId: UUID, download: PersistedDownload) {
        // Find next file to download
        guard let nextFile: BackgroundFileDownload = download.fileDownloads.first(where: { file in
            !download.completedFiles.contains(file.relativePath)
        }) else {
            logger.info("No more files to download")
            return
        }

        logger.info("Starting download of next file: \(nextFile.relativePath)")

        var request: URLRequest = URLRequest(url: nextFile.url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

        let task: URLSessionDownloadTask = backgroundSession.downloadTask(with: request)

        // Store task info in taskDescription for state restoration
        let taskInfo: TaskDescriptionInfo = TaskDescriptionInfo(
            downloadId: downloadId.uuidString,
            filePath: nextFile.relativePath
        )
        if let taskData = try? JSONEncoder().encode(taskInfo),
           let taskDescription: String = String(data: taskData, encoding: .utf8) {
            task.taskDescription = taskDescription
        }

        // Store mappings
        state.setTaskMapping(downloadId: downloadId, file: nextFile, for: task.taskIdentifier)

        task.resume()
    }
}

// MARK: - URLSessionDownloadDelegate

private final class BackgroundDownloadManagerDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private weak var manager: BackgroundDownloadManager?
    private let logger: Logger = Logger(
        subsystem: "com.think.modeldownloader",
        category: "BackgroundDownloadManager"
    )
    private let notificationManager: DownloadNotificationManager?

    init(notificationManager: DownloadNotificationManager? = nil) {
        self.notificationManager = notificationManager
        super.init()
    }

    deinit {
        // Clean up weak reference
        manager = nil
    }

    func setManager(_ manager: BackgroundDownloadManager) {
        self.manager = manager
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let manager else { return }
        let taskId: Int = downloadTask.taskIdentifier

        logger.info("=== DOWNLOAD COMPLETED ===")
        logger.info("Task ID: \(taskId)")
        logger.info("Temp location: \(location.path)")
        logger.info("File exists: \(FileManager.default.fileExists(atPath: location.path))")

        // CRITICAL: Move file to safe location synchronously to prevent iOS from deleting it
        var safeLocation: URL?
        do {
            let safeTemp: URL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ThinkAI/SafeDownloads/\(UUID().uuidString)", isDirectory: false)

            let safeDir: URL = safeTemp.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: safeDir.path) {
                try FileManager.default.createDirectory(at: safeDir, withIntermediateDirectories: true)
            }

            try FileManager.default.moveItem(at: location, to: safeTemp)
            safeLocation = safeTemp
            logger.info("File moved to safe location: \(safeTemp.path)")
        } catch {
            logger.error("Failed to move file to safe location: \(error)")
            // Continue with error handling
        }

        guard let safeLoc: URL = safeLocation else {
            logger.error("No safe location available for task \(taskId)")
            return
        }

        // Check HTTP status code
        guard let response = downloadTask.response as? HTTPURLResponse else {
            logger.error("Invalid response type for task \(taskId)")
            return
        }

        guard (200...299).contains(response.statusCode) else {
            logger.error("Download failed with HTTP status code: \(response.statusCode)")
            // Mark download as failed
            if let downloadInfo = manager.state.getDownloadInfo(for: taskId) {
                let failedDownload: PersistedDownload = downloadInfo.download.updatingProgress(
                    bytesDownloaded: downloadInfo.download.bytesDownloaded,
                    state: DownloadState.failed
                )
                manager.state.setDownload(failedDownload, for: downloadInfo.downloadId)
                manager.state.removeTaskMapping(for: taskId)

                // Send failure notification
                if let notificationManager {
                    Task {
                        let error: NSError = NSError(
                            domain: "HTTPError",
                            code: response.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(response.statusCode) error"]
                        )
                        await notificationManager.scheduleDownloadFailedNotification(
                            for: downloadInfo.downloadId,
                            modelId: downloadInfo.download.modelId,
                            error: error
                        )
                    }
                }

                // Persist failed state
                Task {
                    await manager.stateManager.persistDownload(failedDownload)
                }
            }
            return
        }

        // Get download info synchronously
        guard let downloadInfo: StateContainer.DownloadTaskInfo = manager.state.getDownloadInfo(for: taskId) else {
            logger.error("No download info found for task \(taskId)")
            return
        }

        let download: PersistedDownload = downloadInfo.download
        let downloadId: UUID = downloadInfo.downloadId
        let fileDownload: BackgroundFileDownload = downloadInfo.file

        logger.info("File: \(fileDownload.relativePath)")
        logger.info("Destination: \(fileDownload.localPath.path)")

        // Move file from safe location to final destination
        do {
            // Create destination directory
            let destDir: URL = fileDownload.localPath.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: destDir.path) {
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                logger.info("Created directory: \(destDir.path)")
            }

            // Check if the file is a ZIP that needs extraction
            if BackgroundDownloadManager.isZipFile(fileDownload.localPath) {
                // Get ZIP file info
                let zipSize: Int64 = (
                    try? FileManager.default.attributesOfItem(atPath: safeLoc.path)[.size] as? Int64
                ) ?? 0

                let zipSizeStr: String = ByteCountFormatter.string(fromByteCount: zipSize, countStyle: .binary)
                logger.notice("ZIP file detected for extraction: \(fileDownload.relativePath) [\(zipSizeStr)]")

                // Log pre-extraction directory state
                let extractionDir: URL = fileDownload.localPath.deletingPathExtension()
                if FileManager.default.fileExists(atPath: extractionDir.path) {
                    let existingFiles: [URL] = (try? FileManager.default.contentsOfDirectory(
                        at: extractionDir,
                        includingPropertiesForKeys: nil
                    )) ?? []
                    logger.debug(
                        "Pre-extraction directory state: \(extractionDir.path) - \(existingFiles.count) existing files"
                    )
                } else {
                    logger.debug("Extraction directory does not exist yet: \(extractionDir.path)")
                }

                // First, move the ZIP to a temporary location for extraction
                let tempZipPath: URL = fileDownload.localPath.appendingPathExtension("tmp")
                if FileManager.default.fileExists(atPath: tempZipPath.path) {
                    try FileManager.default.removeItem(at: tempZipPath)
                }
                try FileManager.default.moveItem(at: safeLoc, to: tempZipPath)

                // Extract ZIP contents asynchronously (fire-and-forget)
                let extractor: ZipExtractor = ZipExtractor()
                // extractionDir already defined above

                // Fire-and-forget extraction task
                Task { @Sendable [weak manager] in
                    guard let manager else { return }

                    do {
                        // Extract the ZIP
                        _ = try await extractor.extractZip(
                            at: tempZipPath,
                            to: extractionDir,
                            progressHandler: nil
                        )

                        // Log post-extraction state
                        let extractedFiles: [URL] = (try? FileManager.default.contentsOfDirectory(
                            at: extractionDir,
                            includingPropertiesForKeys: [.fileSizeKey]
                        )) ?? []
                        let totalExtractedSize: Int64 = extractedFiles.reduce(Int64(0)) { total, url in
                            let size: Int = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                            return total + Int64(size)
                        }

                        let extractedSizeStr: String = ByteCountFormatter.string(
                            fromByteCount: totalExtractedSize,
                            countStyle: .binary
                        )
                        logger.notice(
                            "ZIP extraction completed: \(extractedFiles.count) files, \(extractedSizeStr) total"
                        )

                        // Log detailed directory tree of extracted content
                        await kFileTreeLogger.logDirectoryTree(
                            at: extractionDir,
                            context: "Post-extraction directory structure"
                        )

                        // For CoreML models, restructure files to flat directory
                        // Check if this is a CoreML model
                        let isCoreMl: Bool = CoreMLDetector.isCoreMLModel(
                            modelId: download.modelId,
                            backend: download.backend,
                            filePath: fileDownload.relativePath
                        )

                        if isCoreMl {
                            await kFileTreeLogger.logCoreMLModelStructure(at: extractionDir)

                            // Restructure to flat directory structure like MLX models
                            do {
                                try await extractor.restructureCoreMLFiles(at: extractionDir)
                                logger.info("CoreML model files restructured to flat directory")

                                // Log the new structure
                                await kFileTreeLogger.logDirectoryTree(
                                    at: extractionDir,
                                    context: "CoreML model after restructuring"
                                )
                            } catch {
                                let warningMessage: String =
                                    "Failed to restructure CoreML files: \(error.localizedDescription)"
                                logger.warning("\(warningMessage)")

                                // Add warning to download record
                                let warningDownload: PersistedDownload = download.addingWarning(warningMessage)
                                manager.state.setDownload(warningDownload, for: downloadId)
                                Task {
                                    await manager.stateManager.persistDownload(warningDownload)
                                }
                            }
                        }

                        // Delete original ZIP after successful extraction
                        do {
                            try FileManager.default.removeItem(at: tempZipPath)
                            let zipSizeStr: String = ByteCountFormatter.string(
                                fromByteCount: zipSize,
                                countStyle: .binary
                            )
                            logger.info(
                                "🗑️ Original ZIP file deleted: \(tempZipPath.lastPathComponent) [\(zipSizeStr)]"
                            )
                        } catch {
                            let warningMessage: String =
                                "Failed to delete original ZIP file: \(error.localizedDescription)"
                            logger.warning("\(warningMessage)")

                            // Add warning to download record
                            let warningDownload: PersistedDownload = download.addingWarning(warningMessage)
                            manager.state.setDownload(warningDownload, for: downloadId)
                            Task {
                                await manager.stateManager.persistDownload(warningDownload)
                            }
                        }
                    } catch {
                        logger.error("ZIP extraction failed for \(fileDownload.relativePath): \(error)")

                        // Move ZIP to final location for manual extraction
                        do {
                            if FileManager.default.fileExists(atPath: fileDownload.localPath.path) {
                                try FileManager.default.removeItem(at: fileDownload.localPath)
                            }
                            try FileManager.default.moveItem(at: tempZipPath, to: fileDownload.localPath)
                        } catch {
                            logger.error("Failed to move ZIP to final location: \(error)")
                        }

                        // Mark download as failed
                        let failedDownload: PersistedDownload = download.updatingProgress(
                            bytesDownloaded: download.bytesDownloaded,
                            state: DownloadState.failed
                        )
                        manager.state.setDownload(failedDownload, for: downloadId)

                        // Persist failed state
                        Task {
                            await manager.stateManager.persistDownload(failedDownload)
                        }
                    }
                }
            } else {
                // Move non-ZIP files normally
                if FileManager.default.fileExists(atPath: fileDownload.localPath.path) {
                    try FileManager.default.removeItem(at: fileDownload.localPath)
                }

                try FileManager.default.moveItem(at: safeLoc, to: fileDownload.localPath)

                let fileSize: Int64 = (try? FileManager.default.attributesOfItem(
                    atPath: fileDownload.localPath.path
                )[.size] as? Int64) ?? 0
                let fileSizeStr: String = ByteCountFormatter.string(
                    fromByteCount: fileSize,
                    countStyle: .binary
                )
                logger.info("File moved successfully: \(fileDownload.relativePath) [\(fileSizeStr)]")
            }

            // Update download state
            var updatedCompletedFiles: [String] = download.completedFiles
            updatedCompletedFiles.append(fileDownload.relativePath)

            let allCompleted: Bool = updatedCompletedFiles.count >= download.expectedFiles.count

            let updatedDownload: PersistedDownload = download.updatingProgress(
                bytesDownloaded: download.bytesDownloaded + fileDownload.size,
                completedFiles: updatedCompletedFiles,
                state: allCompleted ? DownloadState.completed : DownloadState.downloading
            )
            manager.state.setDownload(updatedDownload, for: downloadId)

            // Persist state update
            Task {
                await manager.stateManager.persistDownload(updatedDownload)
            }

            // Clean up task mappings
            manager.state.removeTaskMapping(for: taskId)

            if allCompleted {
                logger.info("🎉 All files downloaded for model: \(download.modelId)")

                // Send completion notification for this specific model
                if let notificationManager {
                    Task {
                        await notificationManager.scheduleModelCompletionNotification(
                            modelName: download.modelId,
                            modelSize: download.totalBytes
                        )
                    }
                }

                // Send completion callback
                if let callback = manager.state.getProgressCallback(for: downloadId) {
                    let progress: DownloadProgress = DownloadProgress(
                        bytesDownloaded: download.totalBytes,
                        totalBytes: download.totalBytes,
                        filesCompleted: download.expectedFiles.count,
                        totalFiles: download.expectedFiles.count,
                        currentFileName: nil
                    )
                    callback(progress)
                }
            } else {
                // Start next file download
                manager.startNextFileDownload(downloadId: downloadId, download: updatedDownload)
            }
        } catch {
            logger.error("Failed to move file: \(error)")

            // Clean up safe location
            try? FileManager.default.removeItem(at: safeLoc)

            // Mark download as failed
            let failedDownload: PersistedDownload = download.updatingProgress(
                bytesDownloaded: download.bytesDownloaded,
                state: DownloadState.failed
            )
            manager.state.setDownload(failedDownload, for: downloadId)

            // Persist failed state
            Task {
                await manager.stateManager.persistDownload(failedDownload)
            }
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }

        let taskId: Int = task.taskIdentifier

        // Don't treat user cancellation as a failure
        if let urlError: URLError = error as? URLError, urlError.code == .cancelled {
            logger.info("Task \(taskId) was cancelled by the user")
            // Clean up mappings, but don't change state to .failed
            manager?.state.removeTaskMapping(for: taskId)
            return
        }

        logger.error("Task \(taskId) failed with error: \(error)")

        if let downloadInfo = manager?.state.getDownloadInfo(for: taskId) {
            let failedDownload: PersistedDownload = downloadInfo.download.updatingProgress(
                bytesDownloaded: downloadInfo.download.bytesDownloaded,
                state: DownloadState.failed
            )
            manager?.state.setDownload(failedDownload, for: downloadInfo.downloadId)

            // Clean up mappings
            manager?.state.removeTaskMapping(for: taskId)

            // Send failure notification
            if let notificationManager {
                Task {
                    await notificationManager.scheduleDownloadFailedNotification(
                        for: downloadInfo.downloadId,
                        modelId: downloadInfo.download.modelId,
                        error: error
                    )
                }
            }

            // Persist failed state
            Task {
                if let mgr = manager {
                    await mgr.stateManager.persistDownload(failedDownload)
                }
            }
        }
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite _: Int64
    ) {
        let taskId: Int = downloadTask.taskIdentifier

        guard let downloadInfo = manager?.state.getDownloadInfo(for: taskId) else { return }

        let download: PersistedDownload = downloadInfo.download
        let downloadId: UUID = downloadInfo.downloadId
        let file: BackgroundFileDownload = downloadInfo.file

        // Calculate total progress
        let completedBytes: Int64 = download.completedFiles.reduce(Int64(0)) { total, fileName in
            if let file = download.fileDownloads.first(where: { $0.relativePath == fileName }) {
                return total + file.size
            }
            return total
        }

        let totalProgress: Int64 = completedBytes + totalBytesWritten

        // Update progress
        if let callback = manager?.state.getProgressCallback(for: downloadId) {
            let progress: DownloadProgress = DownloadProgress(
                bytesDownloaded: totalProgress,
                totalBytes: download.totalBytes,
                filesCompleted: download.completedFiles.count,
                totalFiles: download.expectedFiles.count,
                currentFileName: file.relativePath
            )
            callback(progress)
        }

        // Persist progress periodically (every ~1MB)
        if totalBytesWritten % (1_024 * 1_024) < bytesWritten {
            Task {
                if let mgr = manager {
                    await mgr.stateManager.updateDownloadProgress(
                        id: downloadId,
                        bytesDownloaded: totalProgress
                    )
                }
            }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.info("Background session finished all events")

        // No longer sending a generic notification here - notifications are sent per model

        if let identifier = session.configuration.identifier {
            manager?.callBackgroundCompletionHandler(for: identifier)
        }
    }
}

// MARK: - Thread-Safe State Container

internal final class StateContainer: @unchecked Sendable {
    private let queue: DispatchQueue = DispatchQueue(
        label: "com.think.modeldownloader.state",
        attributes: .concurrent
    )

    private var activeDownloads: [UUID: PersistedDownload] = [:]
    private var taskToDownloadMap: [Int: UUID] = [:]
    private var taskToFileMap: [Int: BackgroundFileDownload] = [:]
    private var progressCallbacks: [UUID: @Sendable (DownloadProgress) -> Void] = [:]

    func setDownload(_ download: PersistedDownload, for id: UUID) {
        queue.async(flags: .barrier) {
            self.activeDownloads[id] = download
        }
    }

    func getDownload(for id: UUID) -> PersistedDownload? {
        queue.sync {
            self.activeDownloads[id]
        }
    }

    func setProgressCallback(_ callback: @escaping @Sendable (DownloadProgress) -> Void, for id: UUID) {
        queue.async(flags: .barrier) {
            self.progressCallbacks[id] = callback
        }
    }

    func getProgressCallback(for id: UUID) -> (@Sendable (DownloadProgress) -> Void)? {
        queue.sync {
            self.progressCallbacks[id]
        }
    }

    func setTaskMapping(downloadId: UUID, file: BackgroundFileDownload, for taskId: Int) {
        queue.async(flags: .barrier) {
            self.taskToDownloadMap[taskId] = downloadId
            self.taskToFileMap[taskId] = file
        }
    }

    struct DownloadTaskInfo {
        let download: PersistedDownload
        let downloadId: UUID
        let file: BackgroundFileDownload
    }

    func getDownloadInfo(for taskId: Int) -> DownloadTaskInfo? {
        queue.sync {
            guard let downloadId = self.taskToDownloadMap[taskId],
                  let download = self.activeDownloads[downloadId],
                  let file = self.taskToFileMap[taskId] else {
                return nil
            }
            return DownloadTaskInfo(download: download, downloadId: downloadId, file: file)
        }
    }

    func getDownloadId(for taskId: Int) -> UUID? {
        queue.sync {
            self.taskToDownloadMap[taskId]
        }
    }

    func removeTaskMapping(for taskId: Int) {
        queue.async(flags: .barrier) {
            self.taskToDownloadMap.removeValue(forKey: taskId)
            self.taskToFileMap.removeValue(forKey: taskId)
        }
    }

    func getAllActiveDownloads() -> [UUID: PersistedDownload] {
        queue.sync {
            self.activeDownloads
        }
    }

    deinit {
        // No cleanup required
    }
}
