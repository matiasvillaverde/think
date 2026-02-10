import Abstractions
import AsyncAlgorithms
import Database
import Foundation
import OSLog

/// ViewModel responsible for managing model downloads from discovery to persistence
///
/// This ViewModel bridges the gap between discovering models and downloading them,
/// providing a clean non-throwing API for the UI while handling all state
/// management through SwiftData. It uses actor isolation for thread safety while
/// hopping to MainActor only when necessary for database writes.
///
/// This unified ViewModel provides all model-related actions across the application,
/// combining download management with model state operations.
public final actor ModelDownloaderViewModel: ModelDownloaderViewModeling {
    // MARK: - Constants

    /// Progress throttle interval in milliseconds
    private static let progressThrottleMilliseconds: Int = 500

    /// Maximum number of download retries
    private static let maxDownloadRetries: Int = 3

    /// Progress update threshold for database writes (0.5 seconds)
    private static let progressUpdateThresholdSeconds: Double = 0.5

    /// Minimum progress change to trigger update (1%)
    private static let minProgressChangeThreshold: Double = 0.01

    // MARK: - Properties
    /// Database interface for persistence
    let database: DatabaseProtocol
    /// Model downloader service
    let modelDownloader: ModelDownloaderProtocol
    /// Community explorer for model transformation
    private let communityExplorer: CommunityModelsExplorerProtocol
    /// Logger for debugging
    let logger: Logger = Logger(subsystem: "ViewModels", category: "ModelDownloaderViewModel")
    /// Track active downloads
    var activeDownloads: Set<UUID> = []
    /// Track download tasks for cancellation
    var downloadTasks: [UUID: Task<Void, Never>] = [:]
    /// Throttle duration for progress updates (500ms)
    private var progressThrottle: Duration { .milliseconds(Self.progressThrottleMilliseconds) }
    /// Track last progress update time for each download
    var lastProgressUpdate: [UUID: Date] = [:]
    /// Track last progress value for each download
    var lastProgressValue: [UUID: Double] = [:]

    // MARK: - Initialization
    /// Initializes a new ModelDownloaderViewModel
    /// - Parameters:
    ///   - database: Database for model persistence
    ///   - modelDownloader: Service for downloading models
    ///   - communityExplorer: Service for model discovery and transformation
    public init(
        database: DatabaseProtocol,
        modelDownloader: ModelDownloaderProtocol,
        communityExplorer: CommunityModelsExplorerProtocol
    ) {
        self.database = database
        self.modelDownloader = modelDownloader
        self.communityExplorer = communityExplorer
    }

    // MARK: - Public API

    /// Saves a DiscoveredModel to the database without starting the download
    /// Returns the model ID immediately after creating it
    public func save(_ discovery: DiscoveredModel) async -> UUID? {
        let modelName: String = await MainActor.run { discovery.name }
        logger.notice("Saving model to database: \(modelName, privacy: .public)")

        do {
            // Transform DiscoveryModel to SendableModel
            logger.debug("Preparing model for save")
            let sendableModel: SendableModel = try await communityExplorer.prepareForDownload(
                discovery,
                preferredBackend: nil
            )

            // Create model in database
            logger.debug("Creating model in database")
            _ = try await database.write(
                ModelCommands.CreateFromDiscovery(
                    discoveredModel: discovery,
                    sendableModel: sendableModel
                )
            )

            logger.info("Model saved: \(modelName, privacy: .public) (ID: \(sendableModel.id))")

            // Return model ID immediately so UI can update
            return sendableModel.id
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
            await createErrorNotification(
                message: "Failed to save \(discovery.name): \(error.localizedDescription)"
            )
            return nil
        }
    }

    /// Adds a locally-referenced model to the database (no download)
    public func addLocalModel(_ model: LocalModelImport) async -> UUID? {
        logger.notice("Adding local model: \(model.name, privacy: .public)")

        do {
            let modelId: UUID = try await database.write(
                ModelCommands.CreateLocalModel(
                    name: model.name,
                    backend: model.backend,
                    type: model.type,
                    parameters: model.parameters,
                    ramNeeded: model.ramNeeded,
                    size: model.size,
                    locationLocal: model.locationLocal,
                    locationBookmark: model.locationBookmark
                )
            )
            logger.info("Local model saved: \(model.name, privacy: .public) (ID: \(modelId))")
            return modelId
        } catch {
            logger.error("Local model save failed: \(error.localizedDescription)")
            let baseMessage: String = String(localized: "Failed to add local model.", bundle: .module)
            await createErrorNotification(
                message: "\(baseMessage) \(error.localizedDescription)"
            )
            return nil
        }
    }
}

// MARK: - Private Methods

extension ModelDownloaderViewModel {
    func processDownload(sendableModel: SendableModel, discoveryName: String) async {
        await processDownloadWithRetry(
            sendableModel: sendableModel,
            discoveryName: discoveryName,
            retryCount: 0,
            maxRetries: Self.maxDownloadRetries
        )
    }

    func handleProgress(_ progress: DownloadProgress, for sendableModel: SendableModel) async {
        let modelId: UUID = sendableModel.id
        let currentProgress: Double = progress.fractionCompleted
        let now: Date = Date()

        let shouldUpdate: Bool = currentProgress >= 1.0 || currentProgress == 0.0 ||
            lastProgressUpdate[modelId] == nil ||
            now.timeIntervalSince(lastProgressUpdate[modelId] ?? Date.distantPast) >= Self.progressUpdateThresholdSeconds ||
            abs(currentProgress - (lastProgressValue[modelId] ?? 0)) >= Self.minProgressChangeThreshold

        if shouldUpdate {
            lastProgressUpdate[modelId] = now
            lastProgressValue[modelId] = currentProgress
            do {
                try await updateProgressInDatabase(modelId: modelId, progress: currentProgress)
            } catch {
                logger.error("Failed to update progress: \(error.localizedDescription)")
            }
        }
    }

    // Using write instead of writeInBackground for immediate UI updates
    private func updateProgressInDatabase(modelId: UUID, progress: Double) async throws {
        try await database.write(
            ModelCommands.UpdateModelDownloadProgress(
                id: modelId,
                progress: progress
            )
        )
    }
    func createErrorNotification(message: String) async {
        do {
            try await database.writeInBackground(
                NotificationCommands.Create(type: .error, message: message)
            )
        } catch {
            logger.error("Failed to create error notification: \(error.localizedDescription)")
        }
    }
    // No @MainActor needed - cleanup is non-critical background operation
    func cleanupCancelledDownloadInDatabase(modelId: UUID) async throws {
        try await database.writeInBackground(
            ModelCommands.CleanupCancelledDownload(modelId: modelId)
        )
    }
    /// Cancels an active download
    public func cancelDownload(modelId: UUID) async {
        logger.notice("🛑 Cancelling download for model: \(modelId)")
        // Check if download is active
        guard activeDownloads.contains(modelId) else {
            logger.debug("No active download found for model: \(modelId)")
            return
        }

        // Cancel the download task first
        if let task = downloadTasks[modelId] {
            logger.debug("Cancelling download task for model: \(modelId)")
            task.cancel()
        }

        // Cancel the download
        await modelDownloader.cancelDownload(for: modelId.uuidString)

        // Remove from active downloads
        cleanupDownloadTracking(modelId: modelId)

        // Clean up model state in database
        do {
            try await cleanupCancelledDownloadInDatabase(modelId: modelId)
            logger.info("Download cancelled and state cleaned up for model: \(modelId)")
        } catch {
            logger.error("Failed to clean up cancelled download state: \(error.localizedDescription)")
        }
    }

    /// Deletes a model from the user's library.
    ///
    /// - For remote models: remove the SwiftData record entirely (no filesystem work).
    /// - For downloaded hub models: delete files best-effort, then mark as not downloaded so the entry can be re-downloaded.
    /// - For local referenced models: remove the reference (no filesystem work).
    public func delete(modelId: UUID) async {
        logger.notice("🗑️ Deleting model: \(modelId)")

        if activeDownloads.contains(modelId) {
            await cancelDownload(modelId: modelId)
        }

        let modelName: String
        do {
            modelName = try await database.readInBackground(ModelCommands.GetModelName(id: modelId))
        } catch DatabaseError.modelNotFound {
            logger.warning("Model not found in database: \(modelId)")
            await createErrorNotification(message: "Model not found in database")
            return
        } catch {
            logger.error("Failed to retrieve model name: \(error.localizedDescription)")
            await createErrorNotification(message: "Failed to access model information")
            return
        }

        guard let sendableModel = try? await database.read(ModelCommands.GetSendableModel(id: modelId)) else {
            await createErrorNotification(message: "Failed to access model information")
            return
        }

        await deleteModelFilesIfNeeded(sendableModel)

        do {
            switch sendableModel.locationKind {
            case .remote:
                try await database.writeInBackground(ModelCommands.DeleteModel(model: modelId))

            case .huggingFace, .localFile:
                try await database.writeInBackground(ModelCommands.DeleteModelLocation(model: modelId))
            }

            try await database.writeInBackground(
                NotificationCommands.Create(type: .success, message: "Model \(modelName) deleted successfully")
            )
        } catch {
            logger.error("Failed to update model state in database: \(error.localizedDescription)")
            await createErrorNotification(message: "Failed to update model state: \(error.localizedDescription)")
        }
    }

    private func deleteModelFilesIfNeeded(_ sendableModel: SendableModel) async {
        do {
            switch sendableModel.locationKind {
            case .localFile:
                logger.info("Local model reference removed; no files deleted from disk")

            case .remote:
                logger.info("Remote model has no local files; skipping filesystem deletion")

            case .huggingFace:
                try await modelDownloader.deleteModel(model: sendableModel.location)
            }
        } catch {
            logger.warning("Failed to delete model files (may not exist): \(error.localizedDescription)")
        }
    }

    /// Clean up download tracking
    func cleanupDownloadTracking(modelId: UUID) {
        activeDownloads.remove(modelId)
        downloadTasks.removeValue(forKey: modelId)
        lastProgressUpdate.removeValue(forKey: modelId)
        lastProgressValue.removeValue(forKey: modelId)
    }

    // MARK: - Background Downloads

    /// Handles completion for background download sessions, refreshing status in the database.
    @preconcurrency
    public func handleBackgroundDownloadCompletion(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) async {
        logger.notice("Handling background download completion for: \(identifier)")
        modelDownloader.handleBackgroundDownloadCompletion(
            identifier: identifier,
            completionHandler: completionHandler
        )
        let statuses: [BackgroundDownloadStatus] = await modelDownloader.backgroundDownloadStatus()
        for status in statuses {
            let modelId: UUID = status.handle.id
            if status.handle.sessionIdentifier == identifier {
                await handleDownloadStatus(status: status, modelId: modelId)
            }
        }
        logger.info("Background download completion handled for: \(identifier)")
    }

    private func handleDownloadStatus(status: BackgroundDownloadStatus, modelId: UUID) async {
        do {
            switch status.state {
            case .completed:
                try await database.write(ModelCommands.UpdateModelDownloadProgress(id: modelId, progress: 1.0))
                cleanupDownloadTracking(modelId: modelId)
                logger.notice("Model download completed: \(modelId)")

            case .downloading:
                try await updateProgressInDatabase(modelId: modelId, progress: status.progress)

            case .failed:
                cleanupDownloadTracking(modelId: modelId)
                if let error = status.error {
                    await createErrorNotification(message: "Download failed: \(error.localizedDescription)")
                }
                try await cleanupCancelledDownloadInDatabase(modelId: modelId)

            case .paused, .pending:
                logger.debug("Download \(String(describing: status.state)) for model: \(modelId)")

            case .cancelled:
                cleanupDownloadTracking(modelId: modelId)
                try await cleanupCancelledDownloadInDatabase(modelId: modelId)
            }
        } catch {
            logger.error("Failed to update model state: \(error)")
        }
    }

    /// Resumes any background downloads tracked by the downloader.
    public func resumeBackgroundDownloads() async {
        logger.notice("Resuming background downloads")
        do {
            let handles: [BackgroundDownloadHandle] = try await modelDownloader.resumeBackgroundDownloads()
            logger.info("Found \(handles.count) background downloads to resume")
            let statuses: [BackgroundDownloadStatus] = await modelDownloader.backgroundDownloadStatus()
            for status in statuses {
                let modelId: UUID = status.handle.id
                if status.state == .downloading || status.state == .pending {
                    activeDownloads.insert(modelId)
                }
                await handleDownloadStatus(status: status, modelId: modelId)
            }
        } catch {
            logger.error("Failed to resume background downloads: \(error)")
        }
    }

    func handleBackgroundDownloadStart(handle: BackgroundDownloadHandle, modelId: UUID) async throws {
        logger.debug("Received background download handle: \(handle.id)")
        try await updateProgressInDatabase(modelId: modelId, progress: 0.0)
    }

    // MARK: - Model Entry Creation

    /// Creates a database entry for a discovery without starting a download.
    public func createModelEntry(for discovery: DiscoveredModel) async -> UUID? {
        let discoveryName: String = await discovery.name
        logger.notice("Creating model entry for: \(discoveryName, privacy: .public)")
        do {
            let sendableModel: SendableModel = try await communityExplorer.prepareForDownload(discovery, preferredBackend: nil)
            let modelId: UUID = try await database.write(
                ModelCommands.CreateFromDiscovery(
                    discoveredModel: discovery, sendableModel: sendableModel, initialState: .notDownloaded
                )
            )
            logger.info("Model entry created: \(discoveryName, privacy: .public) (ID: \(modelId))")
            return modelId
        } catch {
            logger.error("Model entry creation failed: \(error.localizedDescription)")
            await createErrorNotification(message: "Failed to create entry for \(discoveryName): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Notification Support

    /// Requests permission for download notifications.
    public func requestNotificationPermission() async -> Bool {
        logger.info("Requesting notification permission for download notifications")

        // Request permission through the model downloader
        let granted: Bool = await modelDownloader.requestNotificationPermission()

        logger.info("Notification permission result: \(granted ? "granted" : "denied")")

        return granted
    }
}
