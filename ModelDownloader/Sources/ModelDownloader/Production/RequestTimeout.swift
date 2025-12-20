import Abstractions
import Foundation

/// Protocol for URL session operations with timeout support
internal protocol TimeoutSessionProtocol: Sendable {
    func data(from url: URL, timeout: TimeInterval?) async throws -> (Data, URLResponse)
}

/// Wrapper to add timeout support to requests
internal actor RequestTimeoutWrapper {
    private let session: any TimeoutSessionProtocol
    private let defaultTimeout: TimeInterval
    private let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "com.modeldownloader",
        category: "timeout"
    )

    /// Initialize timeout wrapper
    /// - Parameters:
    ///   - session: Underlying session
    ///   - defaultTimeout: Default timeout in seconds
    internal init(
        session: any TimeoutSessionProtocol,
        defaultTimeout: TimeInterval = 30.0
    ) {
        self.session = session
        self.defaultTimeout = defaultTimeout
    }

    /// Perform request with timeout
    /// - Parameters:
    ///   - url: Request URL
    ///   - timeout: Timeout in seconds (uses default if nil)
    /// - Returns: Data and response
    internal func data(
        from url: URL,
        timeout: TimeInterval? = nil
    ) async throws -> (Data, URLResponse) {
        let actualTimeout: TimeInterval = timeout ?? defaultTimeout

        do {
            return try await session.data(from: url, timeout: actualTimeout)
        } catch {
            // Convert timeout errors to HuggingFaceError
            if (error as NSError).domain == NSURLErrorDomain,
               (error as NSError).code == NSURLErrorTimedOut {
                await logger.warning("Request timed out after \(actualTimeout)s", metadata: ["url": url.absoluteString])
                throw HuggingFaceError.timeout
            }
            throw error
        }
    }
}

/// Extension to add timeout to StreamingDownloader
extension StreamingDownloader {
    /// Create downloader with timeout support
    /// - Parameters:
    ///   - urlSession: URL session to use
    ///   - requestTimeout: Timeout for individual requests
    ///   - streamTimeout: Timeout for streaming operations
    /// - Returns: Configured downloader
    static func withTimeout(
        urlSession: URLSession? = nil,
        requestTimeout: TimeInterval = 30.0,
        streamTimeout: TimeInterval = 300.0
    ) -> StreamingDownloader {
        let session: URLSession = urlSession ?? {
            let config: URLSessionConfiguration = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = requestTimeout
            config.timeoutIntervalForResource = streamTimeout
            return URLSession(configuration: config)
        }()

        return StreamingDownloader(urlSession: session)
    }
}

/// Add timeout to download operations
extension DownloadCoordinator {
    /// Download files with timeout configuration
    /// - Parameters:
    ///   - files: Files to download
    ///   - headers: HTTP headers
    ///   - requestTimeout: Timeout per request
    ///   - totalTimeout: Total operation timeout
    ///   - progressHandler: Progress callback
    /// - Returns: Download results
    func downloadFilesWithTimeout(
        _ files: [FileDownloadInfo],
        headers: [String: String],
        requestTimeout _: TimeInterval = 30.0,
        totalTimeout: TimeInterval? = nil,
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> [DownloadResult] {
        if let totalTimeout {
            // Use task timeout for total operation
            return try await withThrowingTaskGroup(of: [DownloadResult].self) { group in
                group.addTask {
                    try await self.downloadFiles(
                        files,
                        headers: headers,
                        progressHandler: progressHandler
                    )
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(totalTimeout * 1_000_000_000))
                    throw HuggingFaceError.timeout
                }

                let results: [DownloadResult] = try await group.next()!
                group.cancelAll()
                return results
            }
        }
        // Just use per-request timeout
        return try await downloadFiles(
            files,
            headers: headers,
            progressHandler: progressHandler
        )
    }
}
