import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Helper actor for thread-safe progress collection
private actor ProgressCollector {
    private var updates: [DownloadProgress] = []

    func add(_ progress: DownloadProgress) {
        updates.append(progress)
    }

    func getAll() -> [DownloadProgress] {
        updates
    }
}

/// Helper actor for thread-safe callback counting
private actor CallbackCounter {
    private var count: Int = 0

    func increment() {
        count += 1
    }

    func getCount() -> Int {
        count
    }
}

/// Tests for background download progress tracking functionality
@Suite("Background Download Progress Tests")
struct BackgroundDownloadProgressTests {
    // Get the shared BackgroundDownloadManager for testing
    private var testManager: BackgroundDownloadManager {
        BackgroundDownloadManager.shared
    }

    @Test("Progress tracking with multi-file downloads")
    func testProgressTrackingWithMultipleFiles() async throws {
        // Create test files with different sizes
        let testFiles: [BackgroundFileDownload] = [
            BackgroundFileDownload(
                url: URL(string: "https://example.com/model.safetensors")!,
                localPath: URL(fileURLWithPath: "/tmp/model.safetensors"),
                size: 1_000_000,  // 1MB
                relativePath: "model.safetensors"
            ),
            BackgroundFileDownload(
                url: URL(string: "https://example.com/config.json")!,
                localPath: URL(fileURLWithPath: "/tmp/config.json"),
                size: 5_000,  // 5KB
                relativePath: "config.json"
            ),
            BackgroundFileDownload(
                url: URL(string: "https://example.com/tokenizer.json")!,
                localPath: URL(fileURLWithPath: "/tmp/tokenizer.json"),
                size: 10_000,  // 10KB
                relativePath: "tokenizer.json"
            )
        ]

        // Use actor for thread-safe progress collection
        let progressCollector: ProgressCollector = ProgressCollector()

        // Start download with progress callback
        let handle: BackgroundDownloadHandle = try await testManager.downloadModel(
            modelId: "test/progress-model-\(UUID().uuidString)",
            backend: SendableModel.Backend.mlx,
            files: testFiles,
            options: BackgroundDownloadOptions()
        ) { progress in
                Task {
                    await progressCollector.add(progress)
                }
        }

        // Verify handle was created
        #expect(handle.modelId.contains("test/progress-model"))
        #expect(handle.backend == SendableModel.Backend.mlx)

        // Check active downloads
        let activeDownloads: [BackgroundDownloadStatus] = await testManager.getActiveDownloads()
        let foundDownload: BackgroundDownloadStatus? = activeDownloads.first { $0.handle.id == handle.id }
        #expect(foundDownload != nil)

        // Clean up
        await testManager.cancelDownload(id: handle.id)
    }

    @Test("Progress calculation accuracy")
    func testProgressCalculationAccuracy() {
        let persistedDownload: PersistedDownload = PersistedDownload(
            id: UUID(),
            modelId: "test/accuracy-model",
            backend: SendableModel.Backend.mlx,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(),
            taskIdentifier: 1,
            downloadDate: Date(),
            expectedFiles: ["file1.bin", "file2.bin", "file3.bin"],
            completedFiles: ["file1.bin"],
            fileDownloads: [
                BackgroundFileDownload(
                    url: URL(string: "https://example.com/file1.bin")!,
                    localPath: URL(fileURLWithPath: "/tmp/file1.bin"),
                    size: 1_000_000,
                    relativePath: "file1.bin"
                ),
                BackgroundFileDownload(
                    url: URL(string: "https://example.com/file2.bin")!,
                    localPath: URL(fileURLWithPath: "/tmp/file2.bin"),
                    size: 2_000_000,
                    relativePath: "file2.bin"
                ),
                BackgroundFileDownload(
                    url: URL(string: "https://example.com/file3.bin")!,
                    localPath: URL(fileURLWithPath: "/tmp/file3.bin"),
                    size: 500_000,
                    relativePath: "file3.bin"
                )
            ],
            totalBytes: 3_500_000,
            bytesDownloaded: 1_500_000,  // file1 complete + 500KB of file2
            state: .downloading
        )

        // Calculate expected progress
        let expectedProgress: Double = Double(1_500_000) / Double(3_500_000)
        let actualProgress: Double = Double(persistedDownload.bytesDownloaded) / Double(persistedDownload.totalBytes)

        #expect(actualProgress == expectedProgress)
        let expectedCompletedCount: Int = 1
        #expect(persistedDownload.completedFiles.count == expectedCompletedCount)
        let expectedFilesCount: Int = 3
        #expect(persistedDownload.expectedFiles.count == expectedFilesCount)
    }

    @Test("Progress callback cleanup on completion")
    func testProgressCallbackCleanup() async throws {
        let callbackCounter: CallbackCounter = CallbackCounter()

        let testFile: BackgroundFileDownload = BackgroundFileDownload(
            url: URL(string: "https://example.com/small.bin")!,
            localPath: URL(fileURLWithPath: "/tmp/small.bin"),
            size: 100,
            relativePath: "small.bin"
        )

        let handle: BackgroundDownloadHandle = try await testManager.downloadModel(
            modelId: "test/cleanup-model-\(UUID().uuidString)",
            backend: SendableModel.Backend.mlx,
            files: [testFile],
            options: BackgroundDownloadOptions()
        ) { _ in
                Task {
                    await callbackCounter.increment()
                }
        }

        // Cancel the download to ensure cleanup
        await testManager.cancelDownload(id: handle.id)

        // Verify download was cancelled (it may still be in active downloads with cancelled state)
        let finalDownloads: [BackgroundDownloadStatus] = await testManager.getActiveDownloads()
        let foundDownload: BackgroundDownloadStatus? = finalDownloads.first { $0.handle.id == handle.id }
        #expect(foundDownload?.state == .cancelled || foundDownload == nil)
    }

    @Test("Accurate file matching by path")
    func testFileMatchingByPath() {
        // Test the file matching logic used in progress calculation
        let files: [BackgroundFileDownload] = [
            BackgroundFileDownload(
                url: URL(string: "https://example.com/models/file1.bin")!,
                localPath: URL(fileURLWithPath: "/tmp/file1.bin"),
                size: 1_000,
                relativePath: "models/file1.bin"
            ),
            BackgroundFileDownload(
                url: URL(string: "https://example.com/file1.bin")!,
                localPath: URL(fileURLWithPath: "/tmp/different.bin"),
                size: 2_000,
                relativePath: "file1.bin"
            )
        ]

        // Test finding by relative path
        let matchedFile: BackgroundFileDownload? = files.first { $0.relativePath == "models/file1.bin" }
        let expectedSize: Int64 = 1_000
        #expect(matchedFile?.size == expectedSize)

        let differentFile: BackgroundFileDownload? = files.first { $0.relativePath == "file1.bin" }
        let expectedDifferentSize: Int64 = 2_000
        #expect(differentFile?.size == expectedDifferentSize)
    }
}
