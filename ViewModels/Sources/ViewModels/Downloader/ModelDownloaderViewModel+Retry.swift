import Abstractions
import AsyncAlgorithms
import Database
import Foundation
import OSLog

// MARK: - Error Handling and Retry Logic

extension ModelDownloaderViewModel {
    // MARK: - Constants

    /// Nanoseconds multiplier for second-to-nanosecond conversion
    private static let nanosecondsPerSecond: UInt64 = 1_000_000_000

    /// Progress throttle interval in milliseconds for download stream
    private static let downloadStreamThrottleMilliseconds: Int = 500

    /// Retry delay multiplier (seconds per retry attempt)
    private static let retryDelayMultiplier: Double = 2.0

    /// Increment for retry attempt counter
    private static let retryAttemptIncrement: Int = 1

    /// Increment for log display of retry attempts
    private static let retryLogIncrement: Int = 2

    func isRetryableError(_ error: Error) -> Bool {
        let nsError: NSError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorDNSLookupFailed,
                NSURLErrorDataNotAllowed:
                return true

            default:
                return false
            }
        }

        return false
    }

    func handleDownloadError(
        error: Error,
        sendableModel: SendableModel,
        discoveryName: String,
        retryCount: Int,
        maxRetries: Int
    ) async {
        logger.error("Download failed: \(error.localizedDescription)")

        if isRetryableError(error), retryCount < maxRetries {
            await retryDownload(
                sendableModel: sendableModel,
                discoveryName: discoveryName,
                retryCount: retryCount,
                maxRetries: maxRetries
            )
        } else {
            await finalizeFailedDownload(
                sendableModel: sendableModel,
                discoveryName: discoveryName,
                error: error,
                attemptCount: retryCount + 1
            )
        }
    }

    func retryDownload(
        sendableModel: SendableModel,
        discoveryName: String,
        retryCount: Int,
        maxRetries: Int
    ) async {
        logger.info("""
            Retrying download after network error \
            (attempt \(retryCount + Self.retryLogIncrement)/\(maxRetries + Self.retryAttemptIncrement))
            """)

        let delay: Double = Double(retryCount + Self.retryAttemptIncrement) * Self.retryDelayMultiplier
        try? await Task.sleep(nanoseconds: UInt64(delay * Double(Self.nanosecondsPerSecond)))

        await processDownloadWithRetry(
            sendableModel: sendableModel,
            discoveryName: discoveryName,
            retryCount: retryCount + 1,
            maxRetries: maxRetries
        )
    }

    func finalizeFailedDownload(
        sendableModel: SendableModel,
        discoveryName: String,
        error: Error,
        attemptCount: Int
    ) async {
        logger.error("Download failed after \(attemptCount) attempts")
        cleanupDownloadTracking(modelId: sendableModel.id)

        await createErrorNotification(
            message: "Failed to download \(discoveryName): \(error.localizedDescription)"
        )

        do {
            try await cleanupCancelledDownloadInDatabase(modelId: sendableModel.id)
        } catch {
            logger.error("Failed to cleanup cancelled download: \(error.localizedDescription)")
        }
    }

    func processDownloadWithRetry(
        sendableModel: SendableModel,
        discoveryName: String,
        retryCount: Int,
        maxRetries: Int
    ) async {
        logger.info("Starting background download for model (attempt \(retryCount + 1)/\(maxRetries + 1))")

        let options: BackgroundDownloadOptions = BackgroundDownloadOptions(
            enableCellular: false,
            notificationTitle: "\(discoveryName) download complete",
            priority: .normal,
            isDiscretionary: false  // Changed to false for immediate download
        )

        let downloadStream: AsyncThrowingStream<BackgroundDownloadEvent, Error> = modelDownloader.downloadModelInBackground(
            sendableModel: sendableModel.location,
            options: options
        )

        do {
            for try await event in downloadStream._throttle(
                for: .milliseconds(Self.downloadStreamThrottleMilliseconds),
                latest: true  // Explicitly set to get the most recent progress
            ) {
                // Check if task is cancelled before processing each event
                try Task.checkCancellation()

                try await handleDownloadEvent(
                    event: event,
                    sendableModel: sendableModel
                )
            }
        } catch is CancellationError {
            logger.info("Download task cancelled for model: \(sendableModel.id)")
            // Don't treat cancellation as an error, just clean up
            cleanupDownloadTracking(modelId: sendableModel.id)
        } catch {
            await handleDownloadError(
                error: error,
                sendableModel: sendableModel,
                discoveryName: discoveryName,
                retryCount: retryCount,
                maxRetries: maxRetries
            )
        }
    }

    func handleDownloadEvent(
        event: BackgroundDownloadEvent,
        sendableModel: SendableModel
    ) async throws {
        switch event {
        case .progress(let progress):
            await handleProgress(progress, for: sendableModel)

        case .handle(let handle):
            try await handleBackgroundDownloadStart(handle: handle, modelId: sendableModel.id)

        case .completed(let modelInfo):
            logger.notice("Download completed for: \(modelInfo.name)")
            cleanupDownloadTracking(modelId: sendableModel.id)

            // The ModelDownloader has already finalized the download and moved files to the correct location
            // We just need to update the database state

            // First update progress to 1.0
            try await database.write(
                ModelCommands.UpdateModelDownloadProgress(
                    id: sendableModel.id,
                    progress: 1.0
                )
            )

            // Then mark as downloaded
            try await database.write(
                ModelCommands.MarkModelAsDownloaded(
                    id: sendableModel.id
                )
            )

            logger.info("Download completed for model: \(sendableModel.id) at repository location: \(sendableModel.location)")
        }
    }
}

// MARK: - Repository-Based Download Finalization
// NOTE: This section has been removed as finalization is now handled by ModelDownloader
// The ModelDownloader's BackgroundDownloadManager properly moves files to their final location
// and handles CoreML model flattening during the finalization process

// MARK: - Pause/Resume Operations

extension ModelDownloaderViewModel {
    /// Pauses an active download
    public func pauseDownload(modelId: UUID) async {
        logger.notice("Pausing download for model: \(modelId)")

        // Check if download is active in memory first
        if activeDownloads.contains(modelId) {
            logger.debug("Found active download in memory for model: \(modelId)")
        } else {
            logger.debug("No active download found in memory for model: \(modelId)")

            // Check database state - maybe the download is still active in the database
            do {
                let modelState: Model.State = try await database.readInBackground(ModelCommands.GetModelState(id: modelId))
                if case .downloadingActive = modelState {
                    logger.info("Download is active in database, re-adding to activeDownloads")
                    activeDownloads.insert(modelId)
                } else {
                    logger.warning("Model is not in downloading state: \(String(describing: modelState))")
                    await createErrorNotification(
                        message: "Cannot interact with download - no download is currently in progress"
                    )
                    return
                }
            } catch {
                logger.error("Failed to check model state: \(error.localizedDescription)")
                await createErrorNotification(
                    message: "Cannot interact with download - no download is currently in progress"
                )
                return
            }
        }

        do {
            // Cancel the download task first to stop the stream
            if let task = downloadTasks[modelId] {
                logger.debug("Cancelling download task for model: \(modelId)")
                task.cancel()
                downloadTasks.removeValue(forKey: modelId)
            }

            // Get the SendableModel to access location
            let sendableModel: SendableModel = try await database.read(ModelCommands.GetSendableModel(id: modelId))

            // Pause the download service
            await modelDownloader.pauseDownload(for: sendableModel.location)

            // Update model state in database
            try await database.write(
                ModelCommands.PauseDownload(id: modelId)
            )

            logger.info("Download paused for model: \(modelId)")
        } catch {
            logger.error("Failed to pause download: \(error.localizedDescription)")
            await createErrorNotification(
                message: "Failed to pause download: \(error.localizedDescription)"
            )
        }
    }

    /// Resumes a paused download
    public func resumeDownload(modelId: UUID) async {
        logger.notice("Resuming download for model: \(modelId)")

        do {
            // Get the SendableModel from database
            let sendableModel: SendableModel = try await database.read(ModelCommands.GetSendableModel(id: modelId))

            // Get model name for logging
            let modelName: String = try await database.read(ModelCommands.GetModelName(id: modelId))

            // Update model state in database first
            try await database.write(
                ModelCommands.ResumeDownload(id: modelId)
            )

            // Add to active downloads tracking
            activeDownloads.insert(modelId)

            // Resume the download service
            await modelDownloader.resumeDownload(for: sendableModel.location)

            // Start download in a new task
            let downloadTask: Task<Void, Never> = Task {
                await processDownload(sendableModel: sendableModel, discoveryName: modelName)
            }
            downloadTasks[modelId] = downloadTask

            logger.info("Download resumed for model: \(modelId)")
        } catch {
            logger.error("Failed to resume download: \(error.localizedDescription)")
            await createErrorNotification(
                message: "Failed to resume download: \(error.localizedDescription)"
            )
        }
    }
}
