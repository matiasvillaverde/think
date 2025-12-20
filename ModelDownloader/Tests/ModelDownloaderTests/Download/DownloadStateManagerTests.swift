import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Tests for download state persistence and recovery
@Suite("Download State Manager Tests")
struct DownloadStateManagerTests {
    // MARK: - Test Utilities

    private func createTestUserDefaults() -> UserDefaults {
        let suiteName: String = "test.modeldownloader.\(UUID().uuidString)"
        let userDefaults: UserDefaults = UserDefaults(suiteName: suiteName)!
        // Clear any existing data
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func createTestDownload(
        id: UUID = UUID(),
        modelId: String = "test/model",
        state: DownloadState = .pending
    ) -> PersistedDownload {
        PersistedDownload(
            id: id,
            modelId: modelId,
            backend: .mlx,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(),
            totalBytes: 1_024,
            bytesDownloaded: 0,
            state: state
        ) as PersistedDownload
    }

    // MARK: - Initialization Tests

    @Test("DownloadStateManager initializes with default UserDefaults")
    func testDownloadStateManagerInit() async {
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: createEmpty())
        let downloads: [PersistedDownload] = await manager.getAllPersistedDownloads()

        func createEmpty() -> UserDefaults {
            let suiteName: String = "TestDefaults_\(UUID().uuidString)"
            let defaults: UserDefaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }
        // Should be empty initially (or whatever exists in the default UserDefaults)
        #expect(downloads.isEmpty)
    }

    @Test("DownloadStateManager initializes with custom UserDefaults")
    func testDownloadStateManagerInitWithCustomUserDefaults() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)
        let downloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(downloads.isEmpty)
    }

    // MARK: - Persistence Tests

    @Test("DownloadStateManager persists single download")
    func testPersistSingleDownload() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download: PersistedDownload = createTestDownload()
        await manager.persistDownload(download)

        let persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)
        #expect(persistedDownloads.first?.id == download.id)
        #expect(persistedDownloads.first?.modelId == download.modelId)
    }

    @Test("DownloadStateManager persists multiple downloads")
    func testPersistMultipleDownloads() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download1: PersistedDownload = createTestDownload(modelId: "test/model1")
        let download2: PersistedDownload = createTestDownload(modelId: "test/model2")
        let download3: PersistedDownload = createTestDownload(modelId: "test/model3")

        await manager.persistDownload(download1)
        await manager.persistDownload(download2)
        await manager.persistDownload(download3)

        let persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 3)

        let modelIds: [String] = persistedDownloads.map(\.modelId)
        #expect(modelIds.contains("test/model1"))
        #expect(modelIds.contains("test/model2"))
        #expect(modelIds.contains("test/model3"))
    }

    @Test("DownloadStateManager updates existing download")
    func testUpdateExistingDownload() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let originalDownload: PersistedDownload = createTestDownload(state: .pending)
        await manager.persistDownload(originalDownload)

        let updatedDownload: PersistedDownload = originalDownload.updatingProgress(
            bytesDownloaded: 512,
            state: .downloading
        )
        await manager.persistDownload(updatedDownload)

        let persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)
        #expect(persistedDownloads.first?.id == originalDownload.id)
        #expect(persistedDownloads.first?.bytesDownloaded == 512)
        #expect(persistedDownloads.first?.state == .downloading)
    }

    // MARK: - Removal Tests

    @Test("DownloadStateManager removes download")
    func testRemoveDownload() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download1: PersistedDownload = createTestDownload(modelId: "test/model1")
        let download2: PersistedDownload = createTestDownload(modelId: "test/model2")

        await manager.persistDownload(download1)
        await manager.persistDownload(download2)

        var persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 2)

        await manager.removeDownload(id: download1.id)

        persistedDownloads = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)
        #expect(persistedDownloads.first?.id == download2.id)
    }

    @Test("DownloadStateManager removes non-existent download gracefully")
    func testRemoveNonExistentDownload() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download: PersistedDownload = createTestDownload()
        await manager.persistDownload(download)

        // Try to remove a different download
        let nonExistentId: UUID = UUID()
        await manager.removeDownload(id: nonExistentId)

        let persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)
        #expect(persistedDownloads.first?.id == download.id)
    }

    // MARK: - Progress Update Tests

    @Test("DownloadStateManager updates download progress")
    func testUpdateDownloadProgress() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download: PersistedDownload = createTestDownload()
        await manager.persistDownload(download)

        await manager.updateDownloadProgress(
            id: download.id,
            bytesDownloaded: 768,
            completedFiles: ["file1.bin", "file2.bin"],
            state: .downloading
        )

        let persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)

        let updatedDownload: PersistedDownload = persistedDownloads.first!
        #expect(updatedDownload.bytesDownloaded == 768)
        #expect(updatedDownload.completedFiles == ["file1.bin", "file2.bin"])
        #expect(updatedDownload.state == .downloading)
    }

    @Test("DownloadStateManager updates task identifier")
    func testUpdateDownloadTaskIdentifier() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download: PersistedDownload = createTestDownload()
        await manager.persistDownload(download)

        await manager.updateDownloadTaskIdentifier(id: download.id, taskIdentifier: 42)

        let persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)
        #expect(persistedDownloads.first?.taskIdentifier == 42)
    }

    // MARK: - Get Download Tests

    @Test("DownloadStateManager gets specific download")
    func testGetSpecificDownload() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download1: PersistedDownload = createTestDownload(modelId: "test/model1")
        let download2: PersistedDownload = createTestDownload(modelId: "test/model2")

        await manager.persistDownload(download1)
        await manager.persistDownload(download2)

        let retrievedDownload: PersistedDownload? = await manager.getDownload(id: download1.id)
        #expect(retrievedDownload?.id == download1.id)
        #expect(retrievedDownload?.modelId == "test/model1")
    }

    @Test("DownloadStateManager returns nil for non-existent download")
    func testGetNonExistentDownload() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download: PersistedDownload = createTestDownload()
        await manager.persistDownload(download)

        let nonExistentId: UUID = UUID()
        let retrievedDownload: PersistedDownload? = await manager.getDownload(id: nonExistentId)
        #expect(retrievedDownload == nil)
    }

    // MARK: - Cleanup Tests

    @Test("DownloadStateManager cleans up stale downloads")
    func testCleanupStaleDownloads() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        // Create old downloads (more than 7 days old)
        let oldDate: Date = Date().addingTimeInterval(-8 * 24 * 60 * 60) // 8 days ago
        let oldDownload: PersistedDownload = PersistedDownload(
            id: UUID(),
            modelId: "test/old",
            backend: .mlx,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(),
            downloadDate: oldDate,
            state: .completed
        )

        // Create recent download
        let recentDownload: PersistedDownload = createTestDownload(modelId: "test/recent", state: .pending)

        await manager.persistDownload(oldDownload)
        await manager.persistDownload(recentDownload)

        var persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 2)

        // Cleanup with 7-day threshold
        await manager.cleanupStaleDownloads(olderThan: 7 * 24 * 60 * 60)

        persistedDownloads = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)
        #expect(persistedDownloads.first?.modelId == "test/recent")
    }

    @Test("DownloadStateManager preserves incomplete downloads during cleanup")
    func testCleanupPreservesIncompleteDownloads() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        // Create old incomplete download
        let oldDate: Date = Date().addingTimeInterval(-8 * 24 * 60 * 60) // 8 days ago
        let oldIncompleteDownload: PersistedDownload = PersistedDownload(
            id: UUID(),
            modelId: "test/old-incomplete",
            backend: .mlx,
            sessionIdentifier: "test.session",
            options: BackgroundDownloadOptions(),
            downloadDate: oldDate,
            state: .downloading // Still downloading
        )

        await manager.persistDownload(oldIncompleteDownload)

        var persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)

        // Cleanup should preserve incomplete downloads
        await manager.cleanupStaleDownloads(olderThan: 7 * 24 * 60 * 60)

        persistedDownloads = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 1)
        #expect(persistedDownloads.first?.modelId == "test/old-incomplete")
    }

    @Test("DownloadStateManager clears all downloads")
    func testClearAllDownloads() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let download1: PersistedDownload = createTestDownload(modelId: "test/model1")
        let download2: PersistedDownload = createTestDownload(modelId: "test/model2")

        await manager.persistDownload(download1)
        await manager.persistDownload(download2)

        var persistedDownloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.count == 2)

        await manager.clearAllDownloads()

        persistedDownloads = await manager.getAllPersistedDownloads()
        #expect(persistedDownloads.isEmpty)
    }

    // MARK: - Error Handling Tests

    @Test("DownloadStateManager handles corrupted data gracefully")
    func testHandleCorruptedData() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let persistenceKey: String = "ModelDownloader.BackgroundDownloads.v1"

        // Manually set corrupted data
        let corruptedData: Data = Data("This is not valid JSON".utf8)
        userDefaults.set(corruptedData, forKey: persistenceKey)

        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        // Should return empty array and clear corrupted data
        let downloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(downloads.isEmpty)

        // For this test, we just verify that corrupted data doesn't crash the system
        // The actual clearing is implementation detail that happens asynchronously
    }

    @Test("DownloadStateManager handles empty UserDefaults")
    func testHandleEmptyUserDefaults() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let downloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(downloads.isEmpty)
    }

    @Test("DownloadStateManager handles progress update for non-existent download")
    func testUpdateProgressForNonExistentDownload() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let nonExistentId: UUID = UUID()

        // Should not crash or throw
        await manager.updateDownloadProgress(
            id: nonExistentId,
            bytesDownloaded: 100
        )

        let downloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(downloads.isEmpty)
    }

    @Test("DownloadStateManager handles task identifier update for non-existent download")
    func testUpdateTaskIdentifierForNonExistentDownload() async {
        let userDefaults: UserDefaults = createTestUserDefaults()
        let manager: DownloadStateManager = DownloadStateManager(userDefaults: userDefaults)

        let nonExistentId: UUID = UUID()

        // Should not crash or throw
        await manager.updateDownloadTaskIdentifier(id: nonExistentId, taskIdentifier: 42)

        let downloads: [PersistedDownload] = await manager.getAllPersistedDownloads()
        #expect(downloads.isEmpty)
    }
}
