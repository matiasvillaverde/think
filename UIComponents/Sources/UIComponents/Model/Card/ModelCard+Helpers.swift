import Abstractions
import Database
import Foundation
import OSLog
import SwiftUI

// MARK: - Helper Methods Extension

extension ModelCard {
    // MARK: - Message Views

    var confirmationMessage: some View {
        Text(
            """
            To use this model, \(formattedSize) of data will be downloaded
            from the internet. Continue?
            """,
            bundle: .module,
            comment: "Confirmation message for downloading a model from the internet"
        )
    }

    var deleteConfirmationMessage: some View {
        Text(
            "Are you sure you want to delete this model?",
            bundle: .module,
            comment: "Confirmation message text to delete a model"
        )
    }

    var cancelConfirmationMessage: some View {
        Text(
            "Are you sure you want to cancel this download? All progress will be lost.",
            bundle: .module,
            comment: "Confirmation message text to cancel a download"
        )
    }

    // MARK: - Helper Methods

    func handleModelSelection() {
        let logger: Logger = Logger(subsystem: "UIComponents", category: "ModelCard")

        // Allow selection of remote models or downloaded local models
        if model.backend == .remote || model.state?.isDownloaded == true {
            logger.info("Selecting model \(model.displayName) for chat \(chat.id)")
            Task(priority: .userInitiated) {
                dismiss()
                logger.info(
                    "Calling generator.modify with chatId: \(chat.id), modelId: \(model.id)"
                )
                await generator.modify(chatId: chat.id, modelId: model.id)
                logger.info("generator.modify completed")
            }
        } else {
            logger.warning("Model \(model.displayName) is not downloaded, ignoring tap")
        }
        // Note: Removed download() call - downloads should only happen through buttons
    }

    func download() {
        Task(priority: .userInitiated) {
            await modelActions.download(modelId: model.id)
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(model.size),
            countStyle: .file
        )
    }

    func handlePauseDownload() {
        Task(priority: .userInitiated) {
            await modelActions.pauseDownload(modelId: model.id)
        }
    }

    func handleResumeDownload() {
        Task(priority: .userInitiated) {
            await modelActions.resumeDownload(modelId: model.id)
        }
    }

    func handleModelDeletion() {
        Task(priority: .userInitiated) {
            await modelActions.delete(modelId: model.id)
            // Note: Cannot directly set isDeleteConfirmationPresented here
            // The dismissal happens through the dialog's action
        }
    }

    func handleCancelDownload() {
        Task(priority: .userInitiated) {
            await modelActions.cancelDownload(modelId: model.id)
            // Note: Cannot directly set isCancelConfirmationPresented here
            // The dismissal happens through the dialog's action
        }
    }

    func fetchMetricsForModel() -> [Metrics] {
        // For now, return empty array
        // In a real implementation, this would query metrics filtered by model name
        []
    }
}
