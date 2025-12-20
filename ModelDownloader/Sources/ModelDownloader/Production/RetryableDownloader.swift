import Foundation

/// Downloader wrapper that adds retry logic
internal actor RetryableDownloader: StreamingDownloaderProtocol {
    private let downloader: any StreamingDownloaderProtocol
    private let retryPolicy: any RetryPolicy
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.think.modeldownloader",
        category: "RetryableDownloader"
    )

    internal init(
        downloader: any StreamingDownloaderProtocol,
        retryPolicy: any RetryPolicy
    ) {
        self.downloader = downloader
        self.retryPolicy = retryPolicy
    }

    internal func download(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        var lastError: Error?

        for attempt in 0...retryPolicy.maxRetries {
            do {
                if attempt > 0 {
                    let delay: TimeInterval = await retryPolicy.delayForRetry(attempt: attempt)
                    await logger.info(
                        "Retrying download (attempt \(attempt + 1)/\(retryPolicy.maxRetries + 1)) after \(delay)s delay"
                    )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                return try await downloader.download(
                    from: url,
                    to: destination,
                    headers: headers,
                    progressHandler: progressHandler
                )
            } catch {
                lastError = error

                if attempt < retryPolicy.maxRetries {
                    let shouldRetry: Bool = await retryPolicy.shouldRetry(error: error)
                    if shouldRetry {
                        await logger.warning("Download failed, will retry", error: error)
                        continue
                    }
                    await logger.error("Download failed with non-retryable error", error: error)
                    throw error
                }
            }
        }

        await logger.error("Download failed after all retry attempts", error: lastError)
        throw lastError ?? HuggingFaceError.downloadFailed
    }

    internal func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Resume downloads also get retry logic
        var lastError: Error?

        for attempt in 0...retryPolicy.maxRetries {
            do {
                if attempt > 0 {
                    let delay: TimeInterval = await retryPolicy.delayForRetry(attempt: attempt)
                    await logger.info(
                        "Retrying resume download (attempt \(attempt + 1)/\(retryPolicy.maxRetries + 1)) " +
                        "after \(delay)s delay"
                    )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                return try await downloader.downloadResume(
                    from: url,
                    to: destination,
                    headers: headers,
                    progressHandler: progressHandler
                )
            } catch {
                lastError = error

                if attempt < retryPolicy.maxRetries {
                    let shouldRetry: Bool = await retryPolicy.shouldRetry(error: error)
                    if shouldRetry {
                        await logger.warning("Resume download failed, will retry", error: error)
                        continue
                    }
                    await logger.error("Resume download failed with non-retryable error", error: error)
                    throw error
                }
            }
        }

        await logger.error("Resume download failed after all retry attempts", error: lastError)
        throw lastError ?? HuggingFaceError.downloadFailed
    }

    internal func cancel(url: URL) {
        Task {
            await downloader.cancel(url: url)
        }
    }

    internal func cancelAll() {
        Task {
            await downloader.cancelAll()
        }
    }

    internal func pause(url: URL) async {
        await downloader.pause(url: url)
    }

    internal func pauseAll() async {
        await downloader.pauseAll()
    }

    internal func resume(url: URL) async {
        await downloader.resume(url: url)
    }

    internal func resumeAll() async {
        await downloader.resumeAll()
    }
}
