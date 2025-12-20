import Abstractions
import Database
import Foundation
import OSLog

// MARK: - Additional Model Actions Implementation

extension ModelDownloaderViewModel {
    /// Get the local Model for a DiscoveredModel if it exists
    @preconcurrency
    @MainActor
    public func model(for discoveredModel: DiscoveredModel) async -> Model? {
        do {
            // Use the GetModelByLocation command to fetch the model
            return try await database.read(
                ModelCommands.GetModelByLocation(location: discoveredModel.id)
            )
        } catch {
            logger.error("Failed to fetch model for \(discoveredModel.id): \(error)")
            return nil
        }
    }

    /// Download a Model by its ID
    /// Note: This requires the model to already exist in the database
    public func download(modelId: UUID) async {
        logger.info("Starting download for model ID: \(modelId)")

        do {
            // Get the SendableModel from database
            let sendableModel: SendableModel = try await database.read(ModelCommands.GetSendableModel(id: modelId))

            // Track active download
            activeDownloads.insert(modelId)

            // Get model name for logging
            let modelName: String = try await database.read(ModelCommands.GetModelName(id: modelId))

            // Start download in background task and store it for cancellation
            let downloadTask: Task<Void, Never> = Task {
                await processDownload(sendableModel: sendableModel, discoveryName: modelName)
            }
            downloadTasks[modelId] = downloadTask
        } catch {
            logger.error("Failed to start download for ID \(modelId): \(error)")
            await createErrorNotification(
                message: "Failed to start download: \(error.localizedDescription)"
            )
        }
    }

    /// Cancel a download
    @preconcurrency
    @MainActor
    public func cancelDownload(for model: Model) async {
        let modelId: UUID = model.id
        let modelName: String = model.name
        logger.info("Cancelling download for: \(modelName)")
        await cancelDownload(modelId: modelId)
    }

    /// Pause a download
    @preconcurrency
    @MainActor
    public func pauseDownload(for model: Model) async {
        let modelId: UUID = model.id
        let modelName: String = model.name
        logger.info("Pausing download for: \(modelName)")
        await pauseDownload(modelId: modelId)
    }

    /// Resume a download
    @preconcurrency
    @MainActor
    public func resumeDownload(for model: Model) async {
        let modelId: UUID = model.id
        let modelName: String = model.name
        logger.info("Resuming download for: \(modelName)")
        await resumeDownload(modelId: modelId)
    }

    /// Delete a model
    @preconcurrency
    @MainActor
    public func deleteModel(_ model: Model) async {
        let modelId: UUID = model.id
        let modelName: String = model.name
        logger.info("Deleting model: \(modelName)")

        // Cancel any active download first
        await cancelDownload(modelId: modelId)

        // Then delete the model
        await delete(modelId: modelId)
    }
}
