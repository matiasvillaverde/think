import Abstractions
import Foundation

/// Result of a file download operation
internal struct DownloadResult: Sendable {
    internal let url: URL
    internal let localPath: URL
    internal let success: Bool
    internal let error: Error?

    internal init(url: URL, localPath: URL, success: Bool, error: Error? = nil) {
        self.url = url
        self.localPath = localPath
        self.success = success
        self.error = error
    }
}

/// Coordinates multiple file downloads with progress tracking
internal actor DownloadCoordinator {
    internal let downloader: any StreamingDownloaderProtocol
    private let maxConcurrentDownloads: Int
    private var activeDownloads: Set<URL> = []
    private var downloadProgress: DownloadProgress = DownloadProgress.initial(totalBytes: 0, totalFiles: 0)
    private var bytesDownloaded: Int64 = 0
    private let logger: ModelDownloaderLogger

    internal init(
        downloader: (any StreamingDownloaderProtocol)? = nil,
        maxConcurrentDownloads: Int = 4
    ) {
        self.downloader = downloader ?? StreamingDownloader()
        self.maxConcurrentDownloads = max(1, maxConcurrentDownloads)
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "DownloadCoordinator"
        )
    }

    /// Download multiple files with coordinated progress tracking
    /// - Parameters:
    ///   - files: Array of files to download
    ///   - headers: HTTP headers to include in requests
    ///   - progressHandler: Callback for overall download progress
    /// - Returns: Array of download results
    internal func downloadFiles(
        _ files: [FileDownloadInfo],
        headers: [String: String],
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> [DownloadResult] {
        guard !files.isEmpty else { return [] }

        // Initialize progress tracking
        let totalBytes: Int64 = files.reduce(0) { $0 + $1.size }
        downloadProgress = DownloadProgress.initial(
            totalBytes: totalBytes,
            totalFiles: files.count
        )
        bytesDownloaded = 0

        await logger.info("Starting batch download", metadata: [
            "fileCount": files.count,
            "totalBytes": totalBytes,
            "maxConcurrent": maxConcurrentDownloads
        ])

        // Send initial progress
        progressHandler(downloadProgress)

        // Track results - use array to maintain order
        var results: [DownloadResult?] = Array(repeating: nil, count: files.count)

        // Create download tasks with concurrency control
        try await withThrowingTaskGroup(of: (Int, DownloadResult).self) { group in
            var fileIndex: Int = 0

            // Start initial batch of downloads
            for initialIndex in 0..<min(maxConcurrentDownloads, files.count) where initialIndex < files.count {
                let index: Int = initialIndex
                group.addTask {
                    let result: DownloadResult = await self.downloadFile(
                        files[index],
                        headers: headers,
                        progressHandler: progressHandler
                    )
                    return (index, result)
                }
                fileIndex += 1
            }

            // Process results and start new downloads as slots become available
            for try await (index, result) in group {
                results[index] = result

                // Update progress for completed file (success or failure)
                self.updateProgressForCompletedFile()
                progressHandler(downloadProgress)

                // Start next download if available
                if fileIndex < files.count {
                    let nextIndex: Int = fileIndex
                    group.addTask {
                        let result: DownloadResult = await self.downloadFile(
                            files[nextIndex],
                            headers: headers,
                            progressHandler: progressHandler
                        )
                        return (nextIndex, result)
                    }
                    fileIndex += 1
                }
            }

            // Send final progress update after all tasks complete
            downloadProgress = DownloadProgress.completed(
                totalBytes: totalBytes,
                totalFiles: files.count
            )
            progressHandler(downloadProgress)
        }

        // Log final results
        let successCount: Int = results.compactMap(\.self).filter(\.success).count
        let failureCount: Int = results.compactMap(\.self).filter { !$0.success }.count

        await logger.info("Batch download completed", metadata: [
            "totalFiles": files.count,
            "successCount": successCount,
            "failureCount": failureCount,
            "totalBytes": totalBytes
        ])

        // Convert optional array to non-optional
        return results.compactMap(\.self)
    }

    /// Cancel all active downloads
    internal func cancelAll() async {
        let count: Int = activeDownloads.count
        if !activeDownloads.isEmpty {
            await logger.info("Cancelling all active downloads", metadata: ["count": count])
        }
        await downloader.cancelAll()
        activeDownloads.removeAll()
    }

    /// Pause all active downloads
    internal func pauseAll() async {
        let count: Int = activeDownloads.count
        if !activeDownloads.isEmpty {
            await logger.info("Pausing all active downloads", metadata: ["count": count])
        }
        await downloader.pauseAll()
    }

    /// Resume all paused downloads
    internal func resumeAll() async {
        let count: Int = activeDownloads.count
        if !activeDownloads.isEmpty {
            await logger.info("Resuming all paused downloads", metadata: ["count": count])
        }
        await downloader.resumeAll()
    }

    // MARK: - Private Methods

    private func updateProgressForCompletedFile() {
        downloadProgress = downloadProgress.completingFile()
    }

    private func updateProgress(bytesDownloaded: Int64, currentFileName: String) {
        self.bytesDownloaded = bytesDownloaded
        downloadProgress = downloadProgress.updating(
            bytesDownloaded: bytesDownloaded,
            currentFileName: currentFileName
        )
    }

    private func downloadFile(
        _ fileInfo: FileDownloadInfo,
        headers: [String: String],
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void
    ) async -> DownloadResult {
        // Mark download as active
        activeDownloads.insert(fileInfo.url)
        defer { activeDownloads.remove(fileInfo.url) }

        await logger.debug("Starting file download", metadata: [
            "fileName": fileInfo.path,
            "size": fileInfo.size,
            "url": fileInfo.url.absoluteString
        ])

        // Update progress with current file
        updateProgress(bytesDownloaded: bytesDownloaded, currentFileName: fileInfo.path)
        progressHandler(downloadProgress)

        let startBytes: Int64 = bytesDownloaded

        do {
            // Create parent directory if needed
            let parentDir: URL = fileInfo.localPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: parentDir,
                withIntermediateDirectories: true
            )

            // Download with progress tracking
            let downloadedURL: URL = try await downloader.download(
                from: fileInfo.url,
                to: fileInfo.localPath,
                headers: headers
            ) { [weak self] fileProgress in
                    guard let self else { return }

                    let currentBytes: Int64 = startBytes + Int64(Double(fileInfo.size) * fileProgress)

                    Task {
                        await self.updateProgress(bytesDownloaded: currentBytes, currentFileName: fileInfo.path)
                        progressHandler(await self.downloadProgress)
                    }
            }

            // Update total bytes downloaded
            updateProgress(bytesDownloaded: startBytes + fileInfo.size, currentFileName: fileInfo.path)

            await logger.debug("File download completed", metadata: [
                "fileName": fileInfo.path,
                "size": fileInfo.size
            ])

            return DownloadResult(
                url: fileInfo.url,
                localPath: downloadedURL,
                success: true
            )
        } catch {
            // For failed downloads, we still count them as "processed" for progress purposes
            // Update bytes to include this file as if it were downloaded
            updateProgress(bytesDownloaded: startBytes + fileInfo.size, currentFileName: fileInfo.path)

            await logger.error("File download failed", error: error, metadata: [
                "fileName": fileInfo.path,
                "url": fileInfo.url.absoluteString
            ])

            return DownloadResult(
                url: fileInfo.url,
                localPath: fileInfo.localPath,
                success: false,
                error: error
            )
        }
    }
}

/// Enhanced progress tracking for coordinated downloads
extension DownloadProgress {
    /// Calculate progress for a specific file within the overall download
    func progressForFile(at _: Int, fileProgress _: Double) -> DownloadProgress {
        // This would calculate the contribution of a single file's progress
        // to the overall download progress
        self
    }

    /// Create progress for a batch download operation
    static func batchProgress(
        files: [FileDownloadInfo],
        completedFiles: Int,
        currentFileProgress: Double,
        currentFileName: String?
    ) -> DownloadProgress {
        let totalBytes: Int64 = files.reduce(0) { $0 + $1.size }
        let completedBytes: Int64 = files.prefix(completedFiles).reduce(0) { $0 + $1.size }
        let currentFileBytes: Int64 = completedFiles < files.count
            ? Int64(Double(files[completedFiles].size) * currentFileProgress)
            : 0

        return DownloadProgress(
            bytesDownloaded: completedBytes + currentFileBytes,
            totalBytes: totalBytes,
            filesCompleted: completedFiles,
            totalFiles: files.count,
            currentFileName: currentFileName
        )
    }
}
