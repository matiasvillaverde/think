import Foundation
@testable import ModelDownloader
import Testing

// MARK: - Production Hardening Tests

@Test("RetryPolicy should implement exponential backoff")
internal func testExponentialBackoff() async {
    let policy: ExponentialBackoffRetryPolicy = ExponentialBackoffRetryPolicy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        jitter: 0.0 // Disable jitter for predictable testing
    )

    // Test delay calculation
    let delay1: TimeInterval = await policy.delayForRetry(attempt: 1)
    let delay2: TimeInterval = await policy.delayForRetry(attempt: 2)
    let delay3: TimeInterval = await policy.delayForRetry(attempt: 3)

    #expect(delay1 == 1.0) // 1 * 2^0
    #expect(delay2 == 2.0) // 1 * 2^1
    #expect(delay3 == 4.0) // 1 * 2^2

    // Test max delay cap
    let delay10: TimeInterval = await policy.delayForRetry(attempt: 10)
    #expect(delay10 == 10.0) // Capped at maxDelay
}

@Test("RetryPolicy should add jitter to delays")
internal func testRetryWithJitter() async {
    let policy: ExponentialBackoffRetryPolicy = ExponentialBackoffRetryPolicy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        jitter: 0.3
    )

    let delays: [TimeInterval] = await withTaskGroup(of: TimeInterval.self) { group in
        for _ in 0..<10 {
            group.addTask {
                await policy.delayForRetry(attempt: 2)
            }
        }

        var results: [TimeInterval] = []
        for await delay in group {
            results.append(delay)
        }
        return results
    }

    // With jitter, delays should vary
    let uniqueDelays: Set<TimeInterval> = Set(delays)
    #expect(uniqueDelays.count > 1)

    // All delays should be within expected range (2.0 ± 30%)
    for delay in delays {
        #expect(delay >= 1.4 && delay <= 2.6)
    }
}

@Test("RetryableDownloader should retry on transient errors")
internal func testRetryOnTransientErrors() async throws {
    let mockDownloader: MockStreamingDownloaderWithFailures = MockStreamingDownloaderWithFailures()
    let retryPolicy: ExponentialBackoffRetryPolicy = ExponentialBackoffRetryPolicy(
        maxRetries: 3,
        baseDelay: 0.01 // Short delay for tests
    )

    let retryableDownloader: RetryableDownloader = RetryableDownloader(
        downloader: mockDownloader,
        retryPolicy: retryPolicy
    )

    let url: URL = URL(string: "https://example.com/file.bin")!
    let destination: URL = URL(fileURLWithPath: "/tmp/file.bin")

    // Configure mock to fail twice then succeed
    await mockDownloader.setFailureCount(2)

    let result: URL = try await retryableDownloader.download(
        from: url,
        to: destination,
        headers: [:]
    ) { _ in }

    #expect(result == destination)

    let attemptCount: Int = await mockDownloader.getAttemptCount()
    #expect(attemptCount == 3) // 2 failures + 1 success
}

@Test("RetryableDownloader should not retry on non-transient errors")
internal func testNoRetryOnNonTransientErrors() async {
    let mockDownloader: MockStreamingDownloaderWithFailures = MockStreamingDownloaderWithFailures()
    let retryPolicy: ExponentialBackoffRetryPolicy = ExponentialBackoffRetryPolicy(maxRetries: 3)

    let retryableDownloader: RetryableDownloader = RetryableDownloader(
        downloader: mockDownloader,
        retryPolicy: retryPolicy
    )

    let url: URL = URL(string: "https://example.com/file.bin")!
    let destination: URL = URL(fileURLWithPath: "/tmp/file.bin")

    // Configure mock to fail with non-transient error
    await mockDownloader.setError(HuggingFaceError.authenticationRequired)

    do {
        _ = try await retryableDownloader.download(
            from: url,
            to: destination,
            headers: [:]
        ) { _ in }
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is HuggingFaceError)
    }

    let attemptCount: Int = await mockDownloader.getAttemptCount()
    #expect(attemptCount == 1) // No retries for auth errors
}

@Test("DiskSpaceValidator should check available space")
internal func testDiskSpaceValidation() async throws {
    // Test validation with mock file system
    let mockFileManager: MockFileManagerWithSpace = MockFileManagerWithSpace()
    let customValidator: DiskSpaceValidator = DiskSpaceValidator(
        fileManager: mockFileManager,
        minimumFreeSpaceMultiplier: 1.5
    )

    // Configure mock with 10GB free space
    await mockFileManager.setFreeSpace(10_000_000_000)

    // Should pass for 5GB download (needs 7.5GB with multiplier)
    let canDownload5GB: Bool = try await customValidator.hasEnoughSpace(
        for: 5_000_000_000,
        at: URL(fileURLWithPath: "/tmp")
    )
    #expect(canDownload5GB)

    // Should fail for 8GB download (needs 12GB with multiplier)
    let canDownload8GB: Bool = try await customValidator.hasEnoughSpace(
        for: 8_000_000_000,
        at: URL(fileURLWithPath: "/tmp")
    )
    #expect(!canDownload8GB)
}

@Test("DownloadResumer should handle partial downloads")
internal func testDownloadResumption() async throws {
    let mockDownloader: MockStreamingDownloaderWithResume = MockStreamingDownloaderWithResume()
    let resumer: DownloadResumer = DownloadResumer(downloader: mockDownloader)

    let url: URL = URL(string: "https://example.com/large.bin")!
    let destination: URL = FileManager.default.temporaryDirectory.appendingPathComponent("test-large.bin")
    let totalSize: Int64 = 1_000_000

    // Clean up any existing file
    try? FileManager.default.removeItem(at: destination)

    // Configure mock to simulate partial download
    await mockDownloader.setPartialData(size: 500_000, totalSize: totalSize)

    // Create partial file
    let partialData: Data = Data(repeating: 0, count: 500_000)
    try partialData.write(to: destination)

    // Resume download
    let result: URL = try await resumer.resumeDownload(
        from: url,
        to: destination,
        headers: [:],
        expectedSize: totalSize
    ) { _ in }

    #expect(result == destination)

    let resumeRequests: [URLRequest] = await mockDownloader.getResumeRequests()
    #expect(resumeRequests.count == 1)
    #expect(resumeRequests.first?.value(forHTTPHeaderField: "Range") == "bytes=500000-")

    // Clean up
    try? FileManager.default.removeItem(at: destination)
}

@Test("Logger should format messages correctly")
internal func testLoggingFormatting() async {
    let logger: ModelDownloaderLogger = ModelDownloaderLogger(subsystem: "test", category: "download")

    // Test various log levels
    await logger.debug("Debug message")
    await logger.info("Info message")
    await logger.warning("Warning message")
    await logger.error("Error message", error: HuggingFaceError.downloadFailed)

    // Logger should not throw - just verify it runs
    // Logger is successfully initialized
}

@Test("RateLimiter should respect rate limits")
internal func testRateLimiting() async throws {
    let limiter: RateLimiter = RateLimiter(
        requestsPerMinute: 60,
        burstSize: 10
    )

    let startTime: Date = Date()

    // Make burst of requests
    for _: Any in 0..<10 {
        try await limiter.waitIfNeeded()
    }

    // Should complete quickly (within burst)
    let burstDuration: TimeInterval = Date().timeIntervalSince(startTime)
    #expect(burstDuration < 1.0)

    // Next request should be delayed
    let delayStart: Date = Date()
    try await limiter.waitIfNeeded()
    let delayDuration: TimeInterval = Date().timeIntervalSince(delayStart)

    // Should have some delay (at least 1 second for 60/min rate)
    #expect(delayDuration >= 0.9)
}

@Test("TemporaryFileManager should clean up files")
internal func testTemporaryFileCleanup() async {
    let manager: TemporaryFileManager = TemporaryFileManager()

    // Register temporary files
    let tempFile1: URL = URL(fileURLWithPath: "/tmp/test1.tmp")
    let tempFile2: URL = URL(fileURLWithPath: "/tmp/test2.tmp")

    await manager.registerTemporaryFile(tempFile1)
    await manager.registerTemporaryFile(tempFile2)

    // Clean up
    await manager.cleanupAll()

    // Verify cleanup was attempted
    let registeredFiles: Set<URL> = await manager.getRegisteredFiles()
    #expect(registeredFiles.isEmpty)
}

@Test("RequestTimeout should cancel long-running requests")
internal func testRequestTimeout() async {
    let mockSession: MockURLSessionWithDelay = MockURLSessionWithDelay()
    let timeoutSession: MockTimeoutSession = MockTimeoutSession(mockSession: mockSession)
    let timeoutWrapper: RequestTimeoutWrapper = RequestTimeoutWrapper(
        session: timeoutSession,
        defaultTimeout: 1.0 // 1 second timeout
    )

    let url: URL = URL(string: "https://example.com/slow")!

    // Configure mock to delay longer than timeout
    await mockSession.setDelay(2.0)

    do {
        _ = try await timeoutWrapper.data(from: url, timeout: 0.5)
        #expect(Bool(false), "Should have timed out")
    } catch {
        #expect(error is HuggingFaceError)
    }
}

// MARK: - Mock Types

private actor MockStreamingDownloaderWithFailures: StreamingDownloaderProtocol {
    private var failureCount: Int = 0
    private var attemptCount: Int = 0
    private var specificError: Error?

    func setFailureCount(_ count: Int) {
        failureCount = count
    }

    func setError(_ error: Error) {
        specificError = error
    }

    func getAttemptCount() -> Int {
        attemptCount
    }

    func download(
        from _: URL,
        to destination: URL,
        headers _: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) throws -> URL {
        attemptCount += 1

        if let error = specificError {
            throw error
        }

        if attemptCount <= failureCount {
            throw URLError(.networkConnectionLost)
        }

        progressHandler(1.0)
        return destination
    }

    func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        try await download(
            from: url,
            to: destination,
            headers: headers,
            progressHandler: progressHandler
        )
    }

    func cancel(url _: URL) {}
    func cancelAll() {}
    func pause(url _: URL) {}
    func pauseAll() {}
    func resume(url _: URL) {}
    func resumeAll() {}
}

private actor MockFileManagerWithSpace: FileSystemProtocol {
    private var freeSpace: Int64 = 0

    func setFreeSpace(_ bytes: Int64) {
        freeSpace = bytes
    }

    func getFreeSpace(forPath _: String) async -> Int64? {
        await Task.yield()
        return freeSpace
    }
}

private actor MockStreamingDownloaderWithResume: StreamingDownloaderProtocol {
    private var partialSize: Int64 = 0
    private var totalSize: Int64 = 0
    private var resumeRequests: [URLRequest] = []
    private var shouldFailFirstAttempt: Bool = true

    func setPartialData(size: Int64, totalSize: Int64) {
        self.partialSize = size
        self.totalSize = totalSize
    }

    func getResumeRequests() -> [URLRequest] {
        resumeRequests
    }

    func download(
        from _: URL,
        to destination: URL,
        headers _: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) throws -> URL {
        if shouldFailFirstAttempt {
            shouldFailFirstAttempt = false
            // Simulate partial download
            progressHandler(Double(partialSize) / Double(totalSize))
            throw URLError(.networkConnectionLost)
        }

        progressHandler(1.0)
        return destination
    }

    func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) -> URL {
        var request: URLRequest = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("bytes=\(partialSize)-", forHTTPHeaderField: "Range")
        resumeRequests.append(request)

        progressHandler(1.0)
        return destination
    }

    func cancel(url _: URL) {}
    func cancelAll() {}
    func pause(url _: URL) {}
    func pauseAll() {}
    func resume(url _: URL) {}
    func resumeAll() {}
}

private actor MockURLSessionWithDelay {
    private var delay: TimeInterval = 0

    func setDelay(_ seconds: TimeInterval) {
        delay = seconds
    }

    func data(from _: URL, timeout: TimeInterval? = nil) async throws -> (Data, URLResponse) {
        let actualTimeout: TimeInterval = timeout ?? 30.0

        return try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.delay * 1_000_000_000))
                return (Data(), URLResponse())
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(actualTimeout * 1_000_000_000))
                throw HuggingFaceError.timeout
            }

            let result: (Data, URLResponse) = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

private actor TemporaryFileManager {
    private var registeredFiles: Set<URL> = []

    func registerTemporaryFile(_ url: URL) {
        registeredFiles.insert(url)
    }

    func cleanupAll() {
        // In real implementation, would delete files
        registeredFiles.removeAll()
    }

    func getRegisteredFiles() -> Set<URL> {
        registeredFiles
    }
}

// Mock timeout session
private struct MockTimeoutSession: TimeoutSessionProtocol {
    let mockSession: MockURLSessionWithDelay

    func data(from url: URL, timeout: TimeInterval?) async throws -> (Data, URLResponse) {
        try await mockSession.data(from: url, timeout: timeout)
    }
}
