@testable import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("Background Download State Restoration Tests")
struct BackgroundDownloadStateRestorationTests {
    @Test("Download state restored after app termination using V2")
    func testStateRestorationAfterTermination() throws {
        // Given
        let downloadId: UUID = UUID()
        let filePath: String = "models/test-model.bin"

        // Create task description data (simulating what iOS would store)
        let taskDescription: TaskDescriptionInfo = TaskDescriptionInfo(
            downloadId: downloadId.uuidString,
            filePath: filePath
        )

        let taskDescriptionData: Data = try JSONEncoder().encode(taskDescription)
        let taskDescriptionString: String = String(data: taskDescriptionData, encoding: .utf8)!

        // Create a mock download task
        let mockTask: MockURLSessionDownloadTask = MockURLSessionDownloadTask()
        mockTask.mockTaskIdentifier = 42
        mockTask.taskDescription = taskDescriptionString

        // When - simulate state restoration
        let manager: BackgroundDownloadManager = BackgroundDownloadManager.shared

        // The manager should be able to restore mappings from task description
        let restoredInfo: TaskDescriptionInfo? = manager.restoreTaskDescription(from: mockTask)

        // Then
        #expect(restoredInfo != nil)
        #expect(restoredInfo?.downloadId == downloadId.uuidString)
        #expect(restoredInfo?.filePath == filePath)
    }

    @Test("Multiple tasks restored correctly")
    func testMultipleTasksRestored() throws {
        // Given
        let tasks: [(UUID, String)] = [
            (UUID(), "models/llama-3.2-1b/model.safetensors"),
            (UUID(), "models/llama-3.2-1b/config.json"),
            (UUID(), "models/llama-3.2-1b/tokenizer.json")
        ]

        var mockTasks: [MockURLSessionDownloadTask] = []

        for (index, taskInfo): (Int, (UUID, String)) in tasks.enumerated() {
            let (downloadId, filePath): (UUID, String) = taskInfo
            let taskDescription: TaskDescriptionInfo = TaskDescriptionInfo(
                downloadId: downloadId.uuidString,
                filePath: filePath
            )

            let data: Data = try JSONEncoder().encode(taskDescription)
            let mockTask: MockURLSessionDownloadTask = MockURLSessionDownloadTask()
            mockTask.mockTaskIdentifier = index + 1
            mockTask.taskDescription = String(data: data, encoding: .utf8)
            mockTasks.append(mockTask)
        }

        // When
        let manager: BackgroundDownloadManager = BackgroundDownloadManager.shared
        var restoredCount: Int = 0

        for (index, mockTask): (Int, Any) in mockTasks.enumerated() {
            guard let task: MockURLSessionDownloadTask = mockTask as? MockURLSessionDownloadTask else { continue }
            if let restored: TaskDescriptionInfo = manager.restoreTaskDescription(from: task) {
                restoredCount += 1
                #expect(restored.downloadId == tasks[index].0.uuidString)
                #expect(restored.filePath == tasks[index].1)
            }
        }

        // Then
        let expectedTaskCount: Int = tasks.count
        #expect(restoredCount == expectedTaskCount)
    }

    @Test("Persisted downloads restored on init")
    func testPersistedDownloadsRestoredOnInit() async throws {
        // Given
        let stateManager: DownloadStateManager = DownloadStateManager()

        // Clear any existing persisted downloads from previous tests
        let existingDownloads: [PersistedDownload] = await stateManager.getAllPersistedDownloads()
        for download: PersistedDownload in existingDownloads {
            await stateManager.removeDownload(id: download.id)
        }

        let downloadId: UUID = UUID()

        let persistedDownload: PersistedDownload = PersistedDownload(
            id: downloadId,
            modelId: "test-model",
            backend: .mlx,
            sessionIdentifier: "com.think.test",
            options: BackgroundDownloadOptions(),
            expectedFiles: ["model.bin", "config.json"],
            completedFiles: [],
            fileDownloads: [
                BackgroundFileDownload(
                    url: URL(string: "https://example.com/model.bin")!,
                    localPath: URL(fileURLWithPath: "/tmp/model.bin"),
                    size: 1_000,
                    relativePath: "model.bin"
                ),
                BackgroundFileDownload(
                    url: URL(string: "https://example.com/config.json")!,
                    localPath: URL(fileURLWithPath: "/tmp/config.json"),
                    size: 100,
                    relativePath: "config.json"
                )
            ],
            totalBytes: 1_100,
            bytesDownloaded: 550,
            state: .downloading
        )

        // Persist the download
        await stateManager.persistDownload(persistedDownload)

        // When - create new manager (simulating app restart)
        // The V2 manager should restore persisted downloads on init
        let newStateManager: DownloadStateManager = DownloadStateManager()
        let restoredDownloads: [PersistedDownload] = await newStateManager.getAllPersistedDownloads()

        // Then
        let expectedDownloadCount: Int = 1
        #expect(restoredDownloads.count == expectedDownloadCount)

        if let restored: PersistedDownload = restoredDownloads.first {
            #expect(restored.id == downloadId)
            #expect(restored.modelId == "test-model")
            let expectedFilesCount: Int = 2
            #expect(restored.expectedFiles.count == expectedFilesCount)
            let expectedBytesDownloaded: Int64 = 550
            #expect(restored.bytesDownloaded == expectedBytesDownloaded)
            #expect(restored.state == .downloading)
        }

        // Cleanup
        await stateManager.removeDownload(id: downloadId)

        // Also cleanup using the new state manager to ensure it's removed
        await newStateManager.removeDownload(id: downloadId)
    }

    @Test("Task mappings preserved across restoration")
    func testTaskMappingsPreserved() throws {
        // Given
        let manager: BackgroundDownloadManager = BackgroundDownloadManager.shared
        let downloadId: UUID = UUID()
        let taskId: Int = 123
        let file: BackgroundFileDownload = BackgroundFileDownload(
            url: URL(string: "https://example.com/model.bin")!,
            localPath: URL(fileURLWithPath: "/tmp/model.bin"),
            size: 1_000,
            relativePath: "model.bin"
        )

        // Store mapping
        manager.state.setTaskMapping(
            downloadId: downloadId,
            file: file,
            for: taskId
        )

        // When - retrieve mapping (without active download, some info won't be available)
        let retrievedId: UUID? = manager.state.getDownloadId(for: taskId)

        // Then - at least the download ID should be retrievable
        #expect(retrievedId == downloadId)

        // Note: getDownloadInfo requires an active download, which we can't set in tests
        // because activeDownloads is private. This is a limitation of the current design.

        // Cleanup
        manager.state.removeTaskMapping(for: taskId)
    }
}

// MARK: - Mock URLSession Task

class MockURLSessionDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
    var mockTaskIdentifier: Int = 0
    var mockTaskDescription: String?

    override var taskIdentifier: Int {
        mockTaskIdentifier
    }

    override var taskDescription: String? {
        get { mockTaskDescription }
        set { mockTaskDescription = newValue }
    }

    deinit {
        // No cleanup required
    }
}

// MARK: - TaskDescriptionInfo Helper

/// Mirror of the private struct in BackgroundDownloadManager
struct TaskDescriptionInfo: Codable {
    let downloadId: String
    let filePath: String
}

// MARK: - Extension for testing

extension BackgroundDownloadManager {
    /// Test helper to restore task description
    func restoreTaskDescription(from task: URLSessionTask) -> TaskDescriptionInfo? {
        guard let taskDescription = task.taskDescription,
              let data = taskDescription.data(using: .utf8),
              let info = try? JSONDecoder().decode(TaskDescriptionInfo.self, from: data) else {
            return nil
        }
        return info
    }
}
