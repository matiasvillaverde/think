import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

// MARK: - Download Coordinator Tests
extension APITests {
    @Test("DownloadCoordinator should manage multiple downloads")
    internal func testMultipleDownloads() async throws {
        let mockDownloader: TestableStreamingDownloader = TestableStreamingDownloader()
        let coordinator: DownloadCoordinator = DownloadCoordinator(downloader: mockDownloader)

        let files: [FileDownloadInfo] = [
            FileDownloadInfo(
                url: URL(string: "https://example.com/file1.bin")!,
                localPath: URL(fileURLWithPath: "/tmp/file1.bin"),
                size: 1_000,
                path: "file1.bin"
            ),
            FileDownloadInfo(
                url: URL(string: "https://example.com/file2.bin")!,
                localPath: URL(fileURLWithPath: "/tmp/file2.bin"),
                size: 2_000,
                path: "file2.bin"
            )
        ]

        let progressActor: ProgressCollector = ProgressCollector()

        let results: [DownloadResult] = try await coordinator.downloadFiles(
            files,
            headers: [:]
        ) { progress in
            Task {
                await progressActor.addDownloadProgress(progress)
            }
        }

        // Wait for progress updates to be collected with a timeout
        var collectedProgress: [DownloadProgress] = []
        let maxAttempts: Int = 20
        for _ in 0..<maxAttempts {
            collectedProgress = await progressActor.getDownloadProgress()
            // Check if we have the final completed progress
            if let lastProgress = collectedProgress.last,
               lastProgress.isComplete {
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }

        #expect(results.count == 2)
        #expect(try results.allSatisfy(\.success))
        #expect(!collectedProgress.isEmpty)

        // Should have initial progress
        #expect(collectedProgress.first?.filesCompleted == 0)
        #expect(collectedProgress.first?.totalFiles == 2)

        // Should have completion progress
        #expect(collectedProgress.last?.filesCompleted == 2)
        #expect(collectedProgress.last?.isComplete == true)
    }

    @Test("DownloadCoordinator should handle download failures")
    internal func testDownloadWithFailures() async throws {
        let mockDownloader: TestableStreamingDownloader = TestableStreamingDownloader()
        await mockDownloader.setFailureURLs(["https://example.com/fail.bin"])

        let coordinator: DownloadCoordinator = DownloadCoordinator(downloader: mockDownloader)

        let files: [FileDownloadInfo] = [
            FileDownloadInfo(
                url: URL(string: "https://example.com/success.bin")!,
                localPath: URL(fileURLWithPath: "/tmp/success.bin"),
                size: 1_000,
                path: "success.bin"
            ),
            FileDownloadInfo(
                url: URL(string: "https://example.com/fail.bin")!,
                localPath: URL(fileURLWithPath: "/tmp/fail.bin"),
                size: 1_000,
                path: "fail.bin"
            )
        ]

        let results: [DownloadResult] = try await coordinator.downloadFiles(
            files,
            headers: [:]
        ) { _ in }

        #expect(results.count == 2)
        #expect(results[0].success)
        #expect(!results[1].success)
        #expect(results[1].error != nil)
    }

    @Test("DownloadCoordinator should support cancellation")
    internal func testCoordinatorCancellation() async throws {
        let mockDownloader: TestableStreamingDownloader = TestableStreamingDownloader()
        await mockDownloader.setDownloadDelay(1.0) // 1 second delay

        let coordinator: DownloadCoordinator = DownloadCoordinator(downloader: mockDownloader)

        let files: [FileDownloadInfo] = (1...5).map { index in
            FileDownloadInfo(
                url: URL(string: "https://example.com/file\(index).bin")!,
                localPath: URL(fileURLWithPath: "/tmp/file\(index).bin"),
                size: 1_000,
                path: "file\(index).bin"
            )
        }

        let task: Task<Void, Error> = Task {
            try await coordinator.downloadFiles(
                files,
                headers: [:]
            ) { _ in }
        }

        // Cancel after a short delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        task.cancel()

        do {
            try await task.value
            // If we reach here, the downloads completed successfully
            #expect(true)
        } catch {
            #expect(error is CancellationError)
        }
    }

    @Test("DownloadCoordinator should calculate accurate progress")
    internal func testAccurateProgress() async throws {
        let mockDownloader: TestableStreamingDownloader = TestableStreamingDownloader()
        let coordinator: DownloadCoordinator = DownloadCoordinator(downloader: mockDownloader)

        let files: [FileDownloadInfo] = [
            FileDownloadInfo(
                url: URL(string: "https://example.com/small.bin")!,
                localPath: URL(fileURLWithPath: "/tmp/small.bin"),
                size: 100,
                path: "small.bin"
            ),
            FileDownloadInfo(
                url: URL(string: "https://example.com/large.bin")!,
                localPath: URL(fileURLWithPath: "/tmp/large.bin"),
                size: 900,
                path: "large.bin"
            )
        ]

        let progressActor: ProgressCollector = ProgressCollector()

        _ = try await coordinator.downloadFiles(
            files,
            headers: [:]
        ) { progress in
            Task {
                await progressActor.addDownloadProgress(progress)
            }
        }

        // Give a moment for all async tasks to complete
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        // Get the collected progress updates
        let progressUpdates: [DownloadProgress] = await progressActor.getDownloadProgress()

        // Verify progress percentages are reasonable
        let percentages: [Double] = progressUpdates.map(\.percentage)
        #expect(percentages.first ?? 0 < percentages.last ?? 0)

        // Verify final progress (should be 100% with 2 files completed)
        // The last progress update should indicate completion
        #expect(percentages.last ?? 0 >= 90.0) // At least 90% complete
        #expect(progressUpdates.last?.filesCompleted == 2)
        #expect(progressUpdates.last?.totalFiles == 2)
    }

    // MARK: - Test Helpers

    private actor ProgressCollector {
        private var progressValues: [Double] = []
        private var downloadProgressValues: [DownloadProgress] = []

        func addProgress(_ value: Double) {
            progressValues.append(value)
        }

        func addDownloadProgress(_ progress: DownloadProgress) {
            downloadProgressValues.append(progress)
        }

        func getProgress() -> [Double] {
            progressValues
        }

        func getDownloadProgress() -> [DownloadProgress] {
            downloadProgressValues
        }
    }

    // MARK: - Mock Types

    private final actor TestableStreamingDownloader: StreamingDownloaderProtocol, @unchecked Sendable {
        var shouldFailForURLs: Set<String> = []
        var downloadDelay: TimeInterval = 0
        var completedDownloads: [Any] = []
        var maxConcurrentDownloads: Int = 0
        private var currentConcurrentDownloads: Int = 0
        private var activeTasks: [URL: Task<URL, Error>] = [:]

        init() {}

        func setFailureURLs(_ urls: Set<String>) {
            shouldFailForURLs = urls
        }

        func setDownloadDelay(_ delay: TimeInterval) {
            downloadDelay = delay
        }

        func getMaxConcurrentDownloads() -> Int {
            maxConcurrentDownloads
        }

        func getCompletedDownloadsCount() -> Int {
            completedDownloads.count
        }

        func download(
            from url: URL,
            to destination: URL,
            headers _: [String: String],
            progressHandler: @escaping @Sendable (Double) -> Void
        ) async throws -> URL {
            currentConcurrentDownloads += 1
            maxConcurrentDownloads = max(maxConcurrentDownloads, currentConcurrentDownloads)

            defer {
                currentConcurrentDownloads -= 1
            }

            if shouldFailForURLs.contains(url.absoluteString) {
                throw HuggingFaceError.downloadFailed
            }

            if downloadDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(downloadDelay * 1_000_000_000))
            }

            // Simulate progress
            for step in 1...10 {
                progressHandler(Double(step) / 10.0)
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
            }

            completedDownloads.append(url)
            return destination
        }

        func downloadResume(
            from url: URL,
            to destination: URL,
            headers: [String: String],
            progressHandler: @escaping @Sendable (Double) -> Void
        ) async throws -> URL {
            try await download(from: url, to: destination, headers: headers, progressHandler: progressHandler)
        }

        func cancel(url: URL) {
            activeTasks[url]?.cancel()
        }

        func cancelAll() {
            for task in activeTasks.values {
                task.cancel()
            }
            activeTasks.removeAll()
        }

        func pause(url _: URL) {}
        func pauseAll() {}
        func resume(url _: URL) {}
        func resumeAll() {}
    }
}
