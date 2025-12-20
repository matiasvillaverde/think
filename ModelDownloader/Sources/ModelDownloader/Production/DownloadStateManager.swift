import Abstractions
import Foundation

/// Manages persistence and recovery of background download state
internal actor DownloadStateManager {
    private let userDefaults: UserDefaults
    private let persistenceKey: String = "ModelDownloader.BackgroundDownloads.v1"
    private let logger: ModelDownloaderLogger

    /// Initialize with custom UserDefaults (mainly for testing)
    internal init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "DownloadStateManager"
        )
    }

    /// Persist a download to storage
    internal func persistDownload(_ download: PersistedDownload) async {
        await logger.debug("Persisting download state", metadata: [
            "downloadId": download.id.uuidString,
            "modelId": download.modelId,
            "state": download.state.rawValue
        ])

        do {
            var downloads: [PersistedDownload] = await getAllPersistedDownloads()

            // Update existing or add new
            if let index: Array<PersistedDownload>.Index = downloads.firstIndex(where: { $0.id == download.id }) {
                downloads[index] = download
            } else {
                downloads.append(download)
            }

            let data: Data = try JSONEncoder().encode(downloads)
            userDefaults.set(data, forKey: persistenceKey)

            await logger.debug("Download state persisted successfully", metadata: [
                "downloadId": download.id.uuidString,
                "totalDownloads": downloads.count
            ])
        } catch {
            await logger.error("Failed to persist download state", error: error, metadata: [
                "downloadId": download.id.uuidString
            ])
        }
    }

    /// Remove a download from storage
    internal func removeDownload(id: UUID) async {
        await logger.debug("Removing download state", metadata: ["downloadId": id.uuidString])

        do {
            var downloads: [PersistedDownload] = await getAllPersistedDownloads()
            downloads.removeAll { $0.id == id }

            let data: Data = try JSONEncoder().encode(downloads)
            userDefaults.set(data, forKey: persistenceKey)

            await logger.debug("Download state removed successfully", metadata: [
                "downloadId": id.uuidString,
                "remainingDownloads": downloads.count
            ])
        } catch {
            await logger.error("Failed to remove download state", error: error, metadata: [
                "downloadId": id.uuidString
            ])
        }
    }

    /// Get all persisted downloads
    internal func getAllPersistedDownloads() async -> [PersistedDownload] {
        guard let data: Data = userDefaults.data(forKey: persistenceKey) else {
            await logger.debug("No persisted downloads found")
            return []
        }

        do {
            let downloads: [PersistedDownload] = try JSONDecoder().decode([PersistedDownload].self, from: data)
            await logger.debug("Loaded persisted downloads", metadata: ["count": downloads.count])
            return downloads
        } catch {
            await logger.error("Failed to decode persisted downloads", error: error)
            // Clear corrupted data
            userDefaults.removeObject(forKey: persistenceKey)
            return []
        }
    }

    /// Update download progress
    internal func updateDownloadProgress(
        id: UUID,
        bytesDownloaded: Int64,
        completedFiles: [String] = [],
        state: DownloadState? = nil
    ) async {
        await logger.debug("Updating download progress", metadata: [
            "downloadId": id.uuidString,
            "bytesDownloaded": bytesDownloaded,
            "completedFiles": completedFiles.count
        ])

        do {
            var downloads: [PersistedDownload] = await getAllPersistedDownloads()

            guard let index: Array<PersistedDownload>.Index = downloads.firstIndex(where: { $0.id == id }) else {
                await logger.warning("Download not found for progress update", metadata: [
                    "downloadId": id.uuidString
                ])
                return
            }

            downloads[index] = downloads[index].updatingProgress(
                bytesDownloaded: bytesDownloaded,
                completedFiles: completedFiles,
                state: state
            )

            let data: Data = try JSONEncoder().encode(downloads)
            userDefaults.set(data, forKey: persistenceKey)

            await logger.debug("Download progress updated successfully", metadata: [
                "downloadId": id.uuidString
            ])
        } catch {
            await logger.error("Failed to update download progress", error: error, metadata: [
                "downloadId": id.uuidString
            ])
        }
    }

    /// Update download with task identifier
    internal func updateDownloadTaskIdentifier(id: UUID, taskIdentifier: Int) async {
        await logger.debug("Updating download task identifier", metadata: [
            "downloadId": id.uuidString,
            "taskIdentifier": taskIdentifier
        ])

        do {
            var downloads: [PersistedDownload] = await getAllPersistedDownloads()

            guard let index: Array<PersistedDownload>.Index = downloads.firstIndex(where: { $0.id == id }) else {
                await logger.warning("Download not found for task identifier update", metadata: [
                    "downloadId": id.uuidString
                ])
                return
            }

            downloads[index] = downloads[index].updatingProgress(
                bytesDownloaded: downloads[index].bytesDownloaded,
                taskIdentifier: taskIdentifier
            )

            let data: Data = try JSONEncoder().encode(downloads)
            userDefaults.set(data, forKey: persistenceKey)

            await logger.debug("Task identifier updated successfully", metadata: [
                "downloadId": id.uuidString,
                "taskIdentifier": taskIdentifier
            ])
        } catch {
            await logger.error("Failed to update task identifier", error: error, metadata: [
                "downloadId": id.uuidString
            ])
        }
    }

    /// Get a specific download by ID
    internal func getDownload(id: UUID) async -> PersistedDownload? {
        let downloads: [PersistedDownload] = await getAllPersistedDownloads()
        return downloads.first { $0.id == id }
    }

    /// Clean up old/stale downloads
    internal func cleanupStaleDownloads(olderThan timeInterval: TimeInterval = 7 * 24 * 60 * 60) async {
        await logger.info("Starting cleanup of stale downloads", metadata: [
            "maxAge": timeInterval
        ])

        let cutoffDate: Date = Date().addingTimeInterval(-timeInterval)
        let downloads: [PersistedDownload] = await getAllPersistedDownloads()
        let initialCount: Int = downloads.count

        let validDownloads: [PersistedDownload] = downloads.filter { download in
            let isRecent: Bool = download.downloadDate > cutoffDate
            let isNotCompleted: Bool = download.state != .completed && download.state != .failed
            return isRecent || isNotCompleted
        }

        if validDownloads.count != initialCount {
            do {
                let data: Data = try JSONEncoder().encode(validDownloads)
                userDefaults.set(data, forKey: persistenceKey)

                await logger.info("Cleaned up stale downloads", metadata: [
                    "removedCount": initialCount - validDownloads.count,
                    "remainingCount": validDownloads.count
                ])
            } catch {
                await logger.error("Failed to cleanup stale downloads", error: error)
            }
        } else {
            await logger.debug("No stale downloads to cleanup")
        }
    }

    /// Clear all persisted downloads (for testing/reset)
    internal func clearAllDownloads() async {
        await logger.warning("Clearing all persisted downloads")
        userDefaults.removeObject(forKey: persistenceKey)
    }
}
