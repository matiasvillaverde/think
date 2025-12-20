import Foundation

/// Protocol for download session operations
internal protocol DownloadSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func dataTask(with request: URLRequest) -> URLSessionDataTask
    func downloadTask(with request: URLRequest) -> URLSessionDownloadTask
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse)
}

extension URLSession: DownloadSessionProtocol {
    internal func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await self.bytes(for: request, delegate: nil)
    }
}

/// Information for a paused download
internal struct PausedDownloadInfo: Sendable {
    let destination: URL
    let headers: [String: String]
    let progressHandler: @Sendable (Double) -> Void
}

/// Streaming file downloader with progress reporting
internal actor StreamingDownloader {
    private let urlSession: DownloadSessionProtocol
    private var activeTasks: [URL: Task<URL, Error>] = [:]
    private var pausedTasks: [URL: PausedDownloadInfo] = [:]
    private let logger: ModelDownloaderLogger

    internal init(urlSession: DownloadSessionProtocol = URLSession.shared) {
        self.urlSession = urlSession
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "StreamingDownloader"
        )
    }

    /// Download a file with streaming and progress reporting
    /// - Parameters:
    ///   - url: Source URL to download from
    ///   - destination: Local file URL to save to
    ///   - headers: Optional HTTP headers
    ///   - progressHandler: Callback for progress updates (0.0 to 1.0)
    /// - Returns: The destination URL after successful download
    internal func download(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Check if download is already in progress
        if let existingTask = activeTasks[url] {
            await logger.debug("Reusing existing download task", metadata: ["url": url.absoluteString])
            return try await existingTask.value
        }

        await logger.info("Starting download", metadata: [
            "url": url.absoluteString,
            "destination": destination.lastPathComponent
        ])

        // Create download task
        let task: Task<URL, Error> = Task {
            try await performDownload(
                from: url,
                to: destination,
                headers: headers,
                progressHandler: progressHandler
            )
        }

        activeTasks[url] = task

        do {
            let result: URL = try await task.value
            activeTasks.removeValue(forKey: url)
            await logger.info("Download completed successfully", metadata: [
                "url": url.absoluteString,
                "destination": destination.lastPathComponent
            ])
            return result
        } catch {
            activeTasks.removeValue(forKey: url)
            await logger.error("Download failed", error: error, metadata: [
                "url": url.absoluteString,
                "destination": destination.lastPathComponent
            ])
            throw error
        }
    }

    /// Resume a partial download
    /// - Parameters:
    ///   - url: Source URL to download from
    ///   - destination: Local file URL (may contain partial data)
    ///   - headers: Optional HTTP headers
    ///   - progressHandler: Callback for progress updates
    /// - Returns: The destination URL after successful download
    internal func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        var modifiedHeaders: [String: String] = headers

        // Check if partial file exists
        let fileManager: FileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            let attributes: [FileAttributeKey: Any] = try fileManager.attributesOfItem(atPath: destination.path)
            if let fileSize = attributes[.size] as? Int64, fileSize > 0 {
                // Request partial content from where we left off
                modifiedHeaders["Range"] = "bytes=\(fileSize)-"
                await logger.info("Resuming download from byte offset", metadata: [
                    "url": url.absoluteString,
                    "offset": fileSize,
                    "destination": destination.lastPathComponent
                ])
            }
        } else {
            await logger.debug("No existing file to resume, starting fresh download", metadata: [
                "url": url.absoluteString
            ])
        }

        return try await download(
            from: url,
            to: destination,
            headers: modifiedHeaders,
            progressHandler: progressHandler
        )
    }

    /// Cancel a download in progress
    /// - Parameter url: The URL being downloaded
    internal func cancel(url: URL) {
        if activeTasks[url] != nil {
            Task {
                await logger.info("Cancelling download", metadata: ["url": url.absoluteString])
            }
            activeTasks[url]?.cancel()
            activeTasks.removeValue(forKey: url)
        } else {
            Task {
                await logger.debug("No active download to cancel", metadata: ["url": url.absoluteString])
            }
        }
    }

    /// Cancel all active downloads
    internal func cancelAll() {
        let count: Bool = activeTasks.isEmpty
        if !activeTasks.isEmpty {
            Task {
                await logger.info("Cancelling all downloads", metadata: ["count": count])
            }
            for task in activeTasks.values {
                task.cancel()
            }
            activeTasks.removeAll()
        } else {
            Task {
                await logger.debug("No active downloads to cancel")
            }
        }
    }

    /// Pause a specific download
    internal func pause(url: URL) async {
        if let task = activeTasks[url] {
            await logger.info("Pausing download", metadata: ["url": url.absoluteString])
            task.cancel()
            activeTasks.removeValue(forKey: url)
        }
    }

    /// Pause all active downloads
    internal func pauseAll() async {
        if !activeTasks.isEmpty {
            await logger.info("Pausing all downloads", metadata: ["count": activeTasks.count])
            for task in activeTasks.values {
                task.cancel()
            }
            activeTasks.removeAll()
        }
    }

    /// Resume a specific download
    internal func resume(url: URL) async {
        // Note: In a full implementation, this would restore paused downloads
        // For now, this is a placeholder that logs the action
        await logger.info("Attempting to resume download", metadata: ["url": url.absoluteString])
    }

    /// Resume all paused downloads
    internal func resumeAll() async {
        // Note: In a full implementation, this would restore all paused downloads
        // For now, this is a placeholder that logs the action
        await logger.info("Attempting to resume all paused downloads")
    }

    // MARK: - Private Methods

    private func performDownload(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        // Create request
        var request: URLRequest = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Use streaming approach for large files
        await logger.debug("Sending HTTP request", metadata: [
            "url": url.absoluteString,
            "hasRangeHeader": headers["Range"] != nil
        ])

        let (asyncBytes, response): (URLSession.AsyncBytes, URLResponse) = try await urlSession.bytes(for: request)

        guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
            await logger.error("Invalid response type", metadata: ["url": url.absoluteString])
            throw HuggingFaceError.invalidResponse
        }

        await logger.debug("Received HTTP response", metadata: [
            "url": url.absoluteString,
            "statusCode": httpResponse.statusCode,
            "contentLength": httpResponse.expectedContentLength
        ])

        // Check status code
        switch httpResponse.statusCode {
        case 200...299:
            break // Success

        case 401:
            await logger.error("Authentication required", metadata: ["url": url.absoluteString])
            throw HuggingFaceError.authenticationRequired

        case 404:
            await logger.error("File not found", metadata: ["url": url.absoluteString])
            throw HuggingFaceError.fileNotFound

        default:
            await logger.error("HTTP error", metadata: [
                "url": url.absoluteString,
                "statusCode": httpResponse.statusCode
            ])
            throw HuggingFaceError.httpError(statusCode: httpResponse.statusCode)
        }

        // Get total size
        let totalSize: Int64 = httpResponse.expectedContentLength
        let isPartialContent: Bool = httpResponse.statusCode == 206

        if isPartialContent {
            await logger.info("Resuming partial download", metadata: [
                "url": url.absoluteString,
                "totalSize": totalSize > 0 ? totalSize : -1
            ])
        }

        // Create parent directory if needed
        let parentDir: URL = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir,
            withIntermediateDirectories: true
        )

        // Prepare file handle
        let fileHandle: FileHandle
        if isPartialContent, FileManager.default.fileExists(atPath: destination.path) {
            // Append to existing file
            fileHandle = try FileHandle(forWritingTo: destination)
            let currentOffset: UInt64 = try fileHandle.seekToEnd()
            await logger.debug("Appending to existing file", metadata: [
                "destination": destination.lastPathComponent,
                "currentSize": currentOffset
            ])
        } else {
            // Create new file
            FileManager.default.createFile(atPath: destination.path, contents: nil)
            fileHandle = try FileHandle(forWritingTo: destination)
            await logger.debug("Created new file", metadata: [
                "destination": destination.lastPathComponent
            ])
        }

        defer {
            try? fileHandle.close()
        }

        // Stream data to file
        var bytesReceived: Int64 = 0
        let bufferSize: Int = 64 * 1_024 // 64KB chunks
        var buffer: Data = Data()
        var lastProgressLog: Int = -1

        for try await byte in asyncBytes {
            buffer.append(byte)

            if buffer.count >= bufferSize {
                try fileHandle.write(contentsOf: buffer)
                bytesReceived += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)

                // Report progress
                if totalSize > 0 {
                    let progress: Double = Double(bytesReceived) / Double(totalSize)
                    progressHandler(min(progress, 1.0))

                    // Log progress at 25% intervals
                    let progressPercent: Int = Int(progress * 100)
                    if progressPercent >= lastProgressLog + 25 {
                        await logger.debug("Download progress", metadata: [
                            "url": url.absoluteString,
                            "progress": "\(progressPercent)%",
                            "bytesReceived": bytesReceived,
                            "totalBytes": totalSize
                        ])
                        lastProgressLog = progressPercent
                    }
                }
            }

            // Check for cancellation
            try Task.checkCancellation()
        }

        // Write remaining buffer
        if !buffer.isEmpty {
            try fileHandle.write(contentsOf: buffer)
            bytesReceived += Int64(buffer.count)
        }

        // Final progress update
        progressHandler(1.0)

        await logger.info("Download stream completed", metadata: [
            "url": url.absoluteString,
            "bytesReceived": bytesReceived,
            "destination": destination.lastPathComponent
        ])

        return destination
    }
}

/// Background download manager using URLSession download tasks
internal actor BackgroundDownloader {
    private let identifier: String
    private let urlSession: DownloadSessionProtocol
    private var downloadTasks: [Int: DownloadTaskInfo] = [:]
    private var completionHandlers: [Int: (URL?, Error?) -> Void] = [:]

    private struct DownloadTaskInfo {
        let sourceURL: URL
        let destinationURL: URL
        let task: URLSessionDownloadTask
    }

    internal init(identifier: String, urlSession: DownloadSessionProtocol? = nil) {
        self.identifier = identifier

        if let session: DownloadSessionProtocol = urlSession {
            self.urlSession = session
        } else {
            let config: URLSessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
            config.isDiscretionary = false
            config.sessionSendsLaunchEvents = true
            // Note: Implement proper URLSessionDownloadDelegate handling
            // Background downloads require a singleton pattern or shared state to route
            // callbacks to the correct BackgroundDownloader instance. For now, we create
            // the session without a delegate, which means background downloads won't
            // properly resume after app termination.
            self.urlSession = URLSession(configuration: config)
        }
    }

    /// Start a background download
    /// - Parameters:
    ///   - url: Source URL to download
    ///   - destination: Local file URL to save to
    ///   - headers: Optional HTTP headers
    /// - Returns: Task identifier for tracking
    internal func startDownload(
        from url: URL,
        to destination: URL,
        headers: [String: String]
    ) -> String {
        // Create request
        var request: URLRequest = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Create download task
        let task: URLSessionDownloadTask = urlSession.downloadTask(with: request)

        let taskInfo: DownloadTaskInfo = DownloadTaskInfo(
            sourceURL: url,
            destinationURL: destination,
            task: task
        )

        downloadTasks[task.taskIdentifier] = taskInfo

        task.resume()

        return "\(identifier).\(task.taskIdentifier)"
    }

    /// Cancel a background download
    /// - Parameter taskId: Task identifier returned from startDownload
    internal func cancelDownload(taskId: String) {
        guard let taskIdentifier = extractTaskIdentifier(from: taskId) else { return }

        if let taskInfo = downloadTasks[taskIdentifier] {
            taskInfo.task.cancel()
            downloadTasks.removeValue(forKey: taskIdentifier)
            completionHandlers.removeValue(forKey: taskIdentifier)
        }
    }

    /// Handle download completion
    internal func handleDownloadCompletion(
        task: URLSessionDownloadTask,
        location: URL?,
        error: Error?
    ) {
        guard let taskInfo = downloadTasks[task.taskIdentifier] else { return }

        defer {
            downloadTasks.removeValue(forKey: task.taskIdentifier)
        }

        if let location, error == nil {
            // Move file to destination
            do {
                try FileManager.default.moveItem(at: location, to: taskInfo.destinationURL)
                completionHandlers[task.taskIdentifier]?(taskInfo.destinationURL, nil)
            } catch {
                completionHandlers[task.taskIdentifier]?(nil, error)
            }
        } else {
            completionHandlers[task.taskIdentifier]?(nil, error)
        }

        completionHandlers.removeValue(forKey: task.taskIdentifier)
    }

    // MARK: - Private Methods

    private func extractTaskIdentifier(from taskId: String) -> Int? {
        // Handle identifiers with dots by finding the last dot
        guard let lastDotIndex: String.Index = taskId.lastIndex(of: ".") else {
            return nil
        }

        let identifierPart: String = String(taskId[..<lastDotIndex])
        let taskNumberPart: String = String(taskId[taskId.index(after: lastDotIndex)...])

        guard identifierPart == identifier,
              let taskIdentifier: Int = Int(taskNumberPart) else {
            return nil
        }

        return taskIdentifier
    }
}

/// Enhanced URLSession delegate for background downloads with progress tracking
internal final class BackgroundDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onDownloadCompletion: @Sendable (URLSessionDownloadTask, URL?, Error?) -> Void
    private let onProgressUpdate: @Sendable (URLSessionDownloadTask, Int64, Int64, Int64) -> Void
    private let onBackgroundEventsFinished: @Sendable (URLSession) -> Void
    private let logger: ModelDownloaderLogger
    private let notificationManager: DownloadNotificationManager?

    internal init(
        onDownloadCompletion: @escaping @Sendable (URLSessionDownloadTask, URL?, Error?) -> Void,
        onProgressUpdate: @escaping @Sendable (URLSessionDownloadTask, Int64, Int64, Int64) -> Void = { _, _, _, _ in },
        onBackgroundEventsFinished: @escaping @Sendable (URLSession) -> Void = { _ in },
        notificationManager: DownloadNotificationManager? = nil
    ) {
        self.onDownloadCompletion = onDownloadCompletion
        self.onProgressUpdate = onProgressUpdate
        self.onBackgroundEventsFinished = onBackgroundEventsFinished
        self.notificationManager = notificationManager
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "BackgroundDownloadDelegate"
        )
        super.init()
    }

    func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task {
            await logger.info("Background download completed", metadata: [
                "taskIdentifier": downloadTask.taskIdentifier,
                "originalURL": downloadTask.originalRequest?.url?.absoluteString ?? "unknown"
            ])
        }
        onDownloadCompletion(downloadTask, location, nil)
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let downloadTask: URLSessionDownloadTask = task as? URLSessionDownloadTask {
            if let error {
                Task {
                    // Check if error is cancellation
                    let nsError: NSError = error as NSError
                    if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                        await logger.info("Background download cancelled", metadata: [
                            "taskIdentifier": downloadTask.taskIdentifier,
                            "originalURL": downloadTask.originalRequest?.url?.absoluteString ?? "unknown"
                        ])
                    } else {
                        await logger.error("Background download failed", error: error, metadata: [
                            "taskIdentifier": downloadTask.taskIdentifier,
                            "originalURL": downloadTask.originalRequest?.url?.absoluteString ?? "unknown"
                        ])
                    }
                }
                onDownloadCompletion(downloadTask, nil, error)
            }
        }
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task {
            await logger.debug("Background download progress", metadata: [
                "taskIdentifier": downloadTask.taskIdentifier,
                "bytesWritten": bytesWritten,
                "totalBytesWritten": totalBytesWritten,
                "totalBytesExpected": totalBytesExpectedToWrite
            ])
        }
        onProgressUpdate(downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task {
            await logger.info("Background session finished all events", metadata: [
                "sessionIdentifier": session.configuration.identifier ?? "unknown"
            ])

            // Schedule completion notification
            if let notificationManager {
                await notificationManager.scheduleNotification(
                    title: "Downloads Complete",
                    body: "Your models are ready! Tap to open",
                    identifier: "background-download-complete"
                )
            }
        }
        onBackgroundEventsFinished(session)
    }

    deinit {
        // No cleanup required
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        Task {
            await logger.info("Background download resumed", metadata: [
                "taskIdentifier": downloadTask.taskIdentifier,
                "fileOffset": fileOffset,
                "expectedTotalBytes": expectedTotalBytes
            ])
        }
    }
}
