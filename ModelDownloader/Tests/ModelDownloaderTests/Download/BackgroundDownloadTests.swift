import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Comprehensive tests for background download functionality
@Suite("Background Download Tests")
struct BackgroundDownloadTests {
    // MARK: - Test Helpers

    /// Get the shared BackgroundDownloadManager for testing
    private var testManager: BackgroundDownloadManager {
        BackgroundDownloadManager.shared
    }

    // MARK: - BackgroundDownloadManager Tests

    @Test("BackgroundDownloadManager can be initialized")
    func testBackgroundDownloadManagerInit() async {
        let downloads: [BackgroundDownloadStatus] = await testManager.getActiveDownloads()
        // Note: In a real environment, there might be active downloads
        #expect(downloads is [BackgroundDownloadStatus])
    }

    @Test("BackgroundDownloadManager handles empty file list")
    func testBackgroundDownloadManagerEmptyFiles() async {
        do {
            _ = try await testManager.downloadModel(
                modelId: "test/model",
                backend: .mlx,
                files: [],
                options: BackgroundDownloadOptions()
            )
            Issue.record("Should have thrown error for empty files")
        } catch {
            // Expected to fail with empty files
            #expect(error is BackgroundDownloadError)
        }
    }

    @Test("BackgroundDownloadManager creates download handle")
    func testBackgroundDownloadManagerCreatesHandle() async throws {
        let testFile: BackgroundFileDownload = BackgroundFileDownload(
            url: URL(string: "https://example.com/test.bin")!,
            localPath: URL(fileURLWithPath: "/tmp/test.bin"),
            size: 1_024,
            relativePath: "test.bin"
        )

        let handle: BackgroundDownloadHandle = try await testManager.downloadModel(
            modelId: "test/model-\(UUID().uuidString)",
            backend: .mlx,
            files: [testFile],
            options: BackgroundDownloadOptions()
        )

        #expect(handle.modelId.contains("test/model"))
        #expect(handle.backend == SendableModel.Backend.mlx)
        #expect(!handle.id.uuidString.isEmpty)

        // Clean up
        await testManager.cancelDownload(id: handle.id)
    }

    @Test("BackgroundDownloadManager tracks active downloads")
    func testBackgroundDownloadManagerTracksDownloads() async throws {
        let testFile: BackgroundFileDownload = BackgroundFileDownload(
            url: URL(string: "https://example.com/test2.bin")!,
            localPath: URL(fileURLWithPath: "/tmp/test2.bin"),
            size: 1_024,
            relativePath: "test2.bin"
        )

        let handle: BackgroundDownloadHandle = try await testManager.downloadModel(
            modelId: "test/model-track-\(UUID().uuidString)",
            backend: .mlx,
            files: [testFile],
            options: BackgroundDownloadOptions()
        )

        let activeDownloads: [BackgroundDownloadStatus] = await testManager.getActiveDownloads()
        let foundDownload: BackgroundDownloadStatus? = activeDownloads.first { $0.handle.id == handle.id }
        #expect(foundDownload != nil)

        // Clean up
        await testManager.cancelDownload(id: handle.id)
    }

    // MARK: - BackgroundDownloadOptions Tests

    @Test("BackgroundDownloadOptions default values")
    func testBackgroundDownloadOptionsDefaults() {
        let options: BackgroundDownloadOptions = BackgroundDownloadOptions()

        #expect(options.enableCellular == false)
        #expect(options.notificationTitle == nil)
        #expect(options.priority == .normal)
        #expect(options.isDiscretionary == true)
    }

    @Test("BackgroundDownloadOptions custom values")
    func testBackgroundDownloadOptionsCustom() {
        let options: BackgroundDownloadOptions = BackgroundDownloadOptions(
            enableCellular: true,
            notificationTitle: "Custom Title",
            priority: .high,
            isDiscretionary: false
        )

        #expect(options.enableCellular == true)
        #expect(options.notificationTitle == "Custom Title")
        #expect(options.priority == .high)
        #expect(options.isDiscretionary == false)
    }

    @Test("BackgroundDownloadPriority URL session mapping")
    func testBackgroundDownloadPriorityMapping() {
        #expect(BackgroundDownloadPriority.low.urlSessionPriority == URLSessionTask.lowPriority)
        #expect(BackgroundDownloadPriority.normal.urlSessionPriority == URLSessionTask.defaultPriority)
        #expect(BackgroundDownloadPriority.high.urlSessionPriority == URLSessionTask.highPriority)
    }

    // MARK: - PersistedDownload Tests

    @Test("PersistedDownload initialization")
    func testPersistedDownloadInit() {
        let download: PersistedDownload = PersistedDownload(
            id: UUID(),
            modelId: "test/model",
            backend: .mlx,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(),
            totalBytes: 1_024,
            state: DownloadState.pending
        )

        #expect(download.modelId == "test/model")
        #expect(download.backend == SendableModel.Backend.mlx)
        #expect(download.totalBytes == 1_024)
        #expect(download.state == .pending)
        #expect(download.bytesDownloaded == 0)
    }

    @Test("PersistedDownload progress update")
    func testPersistedDownloadProgressUpdate() {
        let originalDownload: PersistedDownload = PersistedDownload(
            id: UUID(),
            modelId: "test/model",
            backend: .mlx,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(),
            totalBytes: 1_024,
            state: DownloadState.pending
        )

        let updatedDownload: PersistedDownload = originalDownload.updatingProgress(
            bytesDownloaded: 512,
            completedFiles: ["file1.bin"],
            state: DownloadState.downloading,
            taskIdentifier: 42
        )

        #expect(updatedDownload.bytesDownloaded == 512)
        #expect(updatedDownload.completedFiles == ["file1.bin"])
        #expect(updatedDownload.state == DownloadState.downloading)
        #expect(updatedDownload.taskIdentifier == 42)

        // Original should be unchanged
        let expectedOriginalBytes: Int64 = 0
        #expect(originalDownload.bytesDownloaded == expectedOriginalBytes)
        #expect(originalDownload.state == .pending)
    }

    @Test("PersistedDownload to handle conversion")
    func testPersistedDownloadToHandle() {
        let download: PersistedDownload = PersistedDownload(
            id: UUID(),
            modelId: "test/model",
            backend: .gguf,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(),
            totalBytes: 1_024
        )

        let handle: BackgroundDownloadHandle = download.toHandle()

        #expect(handle.id == download.id)
        #expect(handle.modelId == download.modelId)
        #expect(handle.backend == download.backend)
        #expect(handle.sessionIdentifier == download.sessionIdentifier)
    }

    // MARK: - BackgroundFileDownload Tests

    @Test("BackgroundFileDownload initialization")
    func testBackgroundFileDownloadInit() {
        let url: URL = URL(string: "https://example.com/model.bin")!
        let localPath: URL = URL(fileURLWithPath: "/tmp/model.bin")

        let fileDownload: BackgroundFileDownload = BackgroundFileDownload(
            url: url,
            localPath: localPath,
            size: 2_048,
            relativePath: "models/model.bin"
        )

        #expect(fileDownload.url == url)
        #expect(fileDownload.localPath == localPath)
        #expect(fileDownload.size == 2_048)
        #expect(fileDownload.relativePath == "models/model.bin")
    }

    // MARK: - BackgroundDownloadStatus Tests

    @Test("BackgroundDownloadStatus creation")
    func testBackgroundDownloadStatusCreation() {
        let handle: BackgroundDownloadHandle = BackgroundDownloadHandle(
            id: UUID(),
            modelId: "test/model",
            backend: .mlx,
            sessionIdentifier: "test.session"
        )

        let status: BackgroundDownloadStatus = BackgroundDownloadStatus(
            handle: handle,
            state: DownloadState.downloading,
            progress: 0.5,
            estimatedTimeRemaining: 300
        )

        #expect(status.handle.id == handle.id)
        #expect(status.state == DownloadState.downloading)
        #expect(status.progress == 0.5)
        #expect(status.error == nil)
        #expect(status.estimatedTimeRemaining == 300)
    }

    // MARK: - DownloadState Tests

    @Test("DownloadState enum cases")
    func testDownloadStateEnumCases() {
        let allCases: [DownloadState] = DownloadState.allCases
        let expectedCases: [DownloadState] = [.pending, .downloading, .paused, .completed, .failed, .cancelled]

        #expect(allCases.count == expectedCases.count)
        for expectedCase: DownloadState in expectedCases {
            #expect(allCases.contains(expectedCase))
        }
    }

    @Test("DownloadState raw values")
    func testDownloadStateRawValues() {
        #expect(DownloadState.pending.rawValue == "pending")
        #expect(DownloadState.downloading.rawValue == "downloading")
        #expect(DownloadState.paused.rawValue == "paused")
        #expect(DownloadState.completed.rawValue == "completed")
        #expect(DownloadState.failed.rawValue == "failed")
        #expect(DownloadState.cancelled.rawValue == "cancelled")
    }

    // MARK: - Error Tests

    @Test("BackgroundDownloadError descriptions")
    func testBackgroundDownloadErrorDescriptions() {
        #expect(BackgroundDownloadError.noFilesToDownload.errorDescription == "No files specified for download")
        #expect(BackgroundDownloadError.downloadNotFound.errorDescription == "Download not found")
        #expect(BackgroundDownloadError.invalidConfiguration.errorDescription == "Invalid download configuration")
    }

    // MARK: - Codable Tests

    @Test("BackgroundDownloadOptions is codable")
    func testBackgroundDownloadOptionsCodable() throws {
        let originalOptions: BackgroundDownloadOptions = BackgroundDownloadOptions(
            enableCellular: true,
            notificationTitle: "Test Title",
            priority: .high,
            isDiscretionary: false
        )

        let encoder: JSONEncoder = JSONEncoder()
        let data: Data = try encoder.encode(originalOptions)

        let decoder: JSONDecoder = JSONDecoder()
        let decodedOptions: BackgroundDownloadOptions = try decoder.decode(BackgroundDownloadOptions.self, from: data)

        #expect(decodedOptions.enableCellular == originalOptions.enableCellular)
        #expect(decodedOptions.notificationTitle == originalOptions.notificationTitle)
        #expect(decodedOptions.priority == originalOptions.priority)
        #expect(decodedOptions.isDiscretionary == originalOptions.isDiscretionary)
    }

    @Test("PersistedDownload is codable")
    func testPersistedDownloadCodable() throws {
        let originalDownload: PersistedDownload = PersistedDownload(
            id: UUID(),
            modelId: "test/model",
            backend: .mlx,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(enableCellular: true),
            taskIdentifier: 42,
            expectedFiles: ["file1.bin", "file2.bin"],
            completedFiles: ["file1.bin"],
            totalBytes: 2_048,
            bytesDownloaded: 1_024,
            state: DownloadState.downloading
        )

        let encoder: JSONEncoder = JSONEncoder()
        let data: Data = try encoder.encode(originalDownload)

        let decoder: JSONDecoder = JSONDecoder()
        let decodedDownload: PersistedDownload = try decoder.decode(PersistedDownload.self, from: data)

        #expect(decodedDownload.id == originalDownload.id)
        #expect(decodedDownload.modelId == originalDownload.modelId)
        #expect(decodedDownload.backend == originalDownload.backend)
        #expect(decodedDownload.sessionIdentifier == originalDownload.sessionIdentifier)
        #expect(decodedDownload.taskIdentifier == originalDownload.taskIdentifier)
        #expect(decodedDownload.expectedFiles == originalDownload.expectedFiles)
        #expect(decodedDownload.completedFiles == originalDownload.completedFiles)
        #expect(decodedDownload.totalBytes == originalDownload.totalBytes)
        #expect(decodedDownload.bytesDownloaded == originalDownload.bytesDownloaded)
        #expect(decodedDownload.state == originalDownload.state)
    }

    @Test("Multi-file download progression and completion")
    func testMultiFileDownloadProgression() {
        let persistedDownload: PersistedDownload = PersistedDownload(
            id: UUID(),
            modelId: "mlx-community/test-model",
            backend: .mlx,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(),
            taskIdentifier: 1,
            downloadDate: Date(),
            expectedFiles: ["model.safetensors", "config.json", "tokenizer.json"],
            completedFiles: [],
            fileDownloads: [
                BackgroundFileDownload(
                    url: URL(string: "https://example.com/model.safetensors")!,
                    localPath: URL(fileURLWithPath: "/tmp/model.safetensors"),
                    size: 1_000_000,
                    relativePath: "model.safetensors"
                ),
                BackgroundFileDownload(
                    url: URL(string: "https://example.com/config.json")!,
                    localPath: URL(fileURLWithPath: "/tmp/config.json"),
                    size: 5_000,
                    relativePath: "config.json"
                ),
                BackgroundFileDownload(
                    url: URL(string: "https://example.com/tokenizer.json")!,
                    localPath: URL(fileURLWithPath: "/tmp/tokenizer.json"),
                    size: 10_000,
                    relativePath: "tokenizer.json"
                )
            ],
            totalBytes: 1_015_000,
            bytesDownloaded: 0,
            state: DownloadState.downloading
        )

        // Test initial state
        #expect(persistedDownload.completedFiles.isEmpty)
        let expectedFilesCount: Int = 3
        #expect(persistedDownload.expectedFiles.count == expectedFilesCount)
        let expectedFileDownloadsCount: Int = 3
        #expect(persistedDownload.fileDownloads.count == expectedFileDownloadsCount)

        // Simulate completing first file
        let afterFirstFile: PersistedDownload = persistedDownload.updatingProgress(
            bytesDownloaded: 1_000_000,
            completedFiles: ["model.safetensors"],
            state: DownloadState.downloading
        )

        let expectedCompletedCount: Int = 1
        #expect(afterFirstFile.completedFiles.count == expectedCompletedCount)
        #expect(afterFirstFile.completedFiles.contains("model.safetensors"))
        #expect(afterFirstFile.state == .downloading)

        // Simulate completing second file
        let afterSecondFile: PersistedDownload = afterFirstFile.updatingProgress(
            bytesDownloaded: 1_005_000,
            completedFiles: ["model.safetensors", "config.json"],
            state: DownloadState.downloading
        )

        let expectedSecondCount: Int = 2
        #expect(afterSecondFile.completedFiles.count == expectedSecondCount)
        #expect(afterSecondFile.completedFiles.contains("config.json"))
        #expect(afterSecondFile.state == DownloadState.downloading)

        // Simulate completing all files
        let completed: PersistedDownload = afterSecondFile.updatingProgress(
            bytesDownloaded: 1_015_000,
            completedFiles: ["model.safetensors", "config.json", "tokenizer.json"],
            state: DownloadState.completed
        )

        let expectedFinalCount: Int = 3
        #expect(completed.completedFiles.count == expectedFinalCount)
        #expect(completed.completedFiles.count == completed.expectedFiles.count)
        #expect(completed.state == DownloadState.completed)
        #expect(completed.bytesDownloaded == completed.totalBytes)
    }
}
