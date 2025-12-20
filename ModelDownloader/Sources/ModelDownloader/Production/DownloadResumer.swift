import Abstractions
import Foundation

/// Manages download resumption for interrupted transfers
internal actor DownloadResumer {
    private let downloader: any StreamingDownloaderProtocol
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.modeldownloader",
        category: "resume"
    )

    internal init(downloader: any StreamingDownloaderProtocol) {
        self.downloader = downloader
    }

    /// Download with automatic resumption support
    /// - Parameters:
    ///   - url: Source URL
    ///   - destination: Local destination
    ///   - headers: HTTP headers
    ///   - expectedSize: Expected file size (for validation)
    ///   - progressHandler: Progress callback
    /// - Returns: Downloaded file URL
    internal func download(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        expectedSize: Int64? = nil,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Check if partial file exists
        if FileManager.default.fileExists(atPath: destination.path) {
            let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: destination.path)
            let currentSize: Int64 = (attributes[.size] as? Int64) ?? 0

            if let expected = expectedSize, currentSize < expected {
                await logger.info("Found partial file (\(currentSize)/\(expected) bytes), attempting resume")
                return try await resumeDownload(
                    from: url,
                    to: destination,
                    headers: headers,
                    expectedSize: expected,
                    progressHandler: progressHandler
                )
            }
            if currentSize > 0, expectedSize == nil {
                // We have a file but don't know if it's complete
                await logger.warning("Found existing file of unknown completeness, attempting resume")
                return try await resumeDownload(
                    from: url,
                    to: destination,
                    headers: headers,
                    expectedSize: nil,
                    progressHandler: progressHandler
                )
            }
        }

        // No partial file, start fresh download
        return try await downloader.download(
            from: url,
            to: destination,
            headers: headers,
            progressHandler: progressHandler
        )
    }

    /// Resume an interrupted download
    /// - Parameters:
    ///   - url: Source URL
    ///   - destination: Local destination with partial data
    ///   - headers: HTTP headers
    ///   - expectedSize: Expected total file size
    ///   - progressHandler: Progress callback
    /// - Returns: Downloaded file URL
    internal func resumeDownload(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        expectedSize: Int64? = nil,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Get current file size
        let currentSize: Int64 = try getCurrentFileSize(at: destination)

        // Validate against expected size
        if let expected = expectedSize {
            if currentSize >= expected {
                await logger.info("File already complete (\(currentSize) bytes)")
                progressHandler(1.0)
                return destination
            }
        }

        // Create resume headers
        var resumeHeaders: [String: String] = headers
        resumeHeaders["Range"] = "bytes=\(currentSize)-"

        await logger.info("Resuming download from byte \(currentSize)")

        // Attempt resume
        return try await downloader.downloadResume(
            from: url,
            to: destination,
            headers: resumeHeaders
        ) { progress in
                // Adjust progress based on already downloaded portion
                if let expected = expectedSize, expected > 0 {
                    let totalProgress: Double = (Double(currentSize) +
                                       (Double(expected - currentSize) * progress)) / Double(expected)
                    progressHandler(min(1.0, totalProgress))
                } else {
                    progressHandler(progress)
                }
        }
    }

    /// Check if a download can be resumed
    /// - Parameters:
    ///   - url: Source URL
    ///   - destination: Local destination
    /// - Returns: Tuple of (canResume, currentBytes)
    internal func canResume(
        url _: URL,
        destination: URL
    ) async -> (canResume: Bool, currentBytes: Int64) {
        guard FileManager.default.fileExists(atPath: destination.path) else {
            return (false, 0)
        }

        do {
            let currentSize: Int64 = try getCurrentFileSize(at: destination)
            return (currentSize > 0, currentSize)
        } catch {
            await logger.warning("Failed to check file size for resume", error: error)
            return (false, 0)
        }
    }

    // MARK: - Private Helpers

    private func getCurrentFileSize(at url: URL) throws -> Int64 {
        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? Int64) ?? 0
    }
}

/// Extension for coordinated downloads with resume support
extension DownloadCoordinator {
    /// Download files with automatic resume support
    /// - Parameters:
    ///   - files: Files to download
    ///   - headers: HTTP headers
    ///   - enableResume: Whether to enable resume for partial downloads
    ///   - progressHandler: Progress callback
    /// - Returns: Download results
    func downloadFilesWithResume(
        _ files: [FileDownloadInfo],
        headers: [String: String],
        enableResume: Bool = true,
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> [DownloadResult] {
        if enableResume {
            // Use DownloadResumer with the coordinator's configured downloader
            let resumer: DownloadResumer = DownloadResumer(downloader: self.downloader)

            var results: [DownloadResult] = []
            for (index, file) in files.enumerated() {
                do {
                    // Ensure parent directory exists before downloading
                    let parentDir: URL = file.localPath.deletingLastPathComponent()
                    try FileManager.default.createDirectory(
                        at: parentDir,
                        withIntermediateDirectories: true
                    )

                    let downloadedURL: URL = try await resumer.download(
                        from: file.url,
                        to: file.localPath,
                        headers: headers,
                        expectedSize: file.size
                    ) { fileProgress in
                        // Calculate overall progress
                        let overallProgress: DownloadProgress = DownloadProgress.batchProgress(
                            files: files,
                            completedFiles: index,
                            currentFileProgress: fileProgress,
                            currentFileName: file.path
                        )
                        progressHandler(overallProgress)
                    }

                    // Verify the file was actually downloaded
                    if !FileManager.default.fileExists(atPath: downloadedURL.path) {
                        throw CocoaError(.fileNoSuchFile, userInfo: [
                            NSFilePathErrorKey: downloadedURL.path,
                            NSURLErrorKey: downloadedURL
                        ])
                    }

                    results.append(DownloadResult(
                        url: file.url,
                        localPath: downloadedURL,
                        success: true
                    ))
                } catch {
                    print("[DownloadResumer] Failed to download \(file.path): \(error)")
                    results.append(DownloadResult(
                        url: file.url,
                        localPath: file.localPath,
                        success: false,
                        error: error
                    ))
                }
            }
            return results
        }
        // Use regular download without resume
        return try await downloadFiles(
            files,
            headers: headers,
            progressHandler: progressHandler
        )
    }
}
