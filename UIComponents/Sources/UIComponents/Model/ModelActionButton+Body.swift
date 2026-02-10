import Abstractions
import Database
import Foundation
import SwiftUI

extension ModelActionButton {
    internal var body: some View {
        Group {
            if let model = currentModel {
                // We have a model in the database - show appropriate action
                modelStateButton(for: model.state ?? .notDownloaded)
            } else if shouldShowDownload {
                // No model yet but we have discovered info - show download
                downloadButton
            }
        }
        .modelActionConfirmations(
            showDownloadConfirmation: showDownloadConfirmationBinding,
            showDeleteConfirmation: showDeleteConfirmationBinding,
            modelSize: modelSize,
            onDownload: handleDownload,
            onDelete: handleDelete
        )
        .onChange(of: currentModel?.downloadProgress) { _, newValue in
            if let newProgress = newValue, let model = currentModel {
                updateDownloadMetrics(newProgress: newProgress, modelSize: model.size)
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func modelStateButton(for state: Model.State) -> some View {
        switch state {
        case .notDownloaded:
            downloadButton

        case .downloadingActive:
            ModelActionButtonDownloadViews(
                progress: currentModel?.downloadProgress ?? 0.0,
                sizeInBytes: sizeInBytes,
                downloadSpeed: downloadSpeed,
                estimatedTimeRemaining: estimatedTimeRemaining,
                isActive: true,
                onPause: handlePause,
                onResume: {
                    // Not used for active state
                },
                onCancel: {
                    // Not used for active state
                }
            )

        case .downloadingPaused:
            ModelActionButtonDownloadViews(
                progress: currentModel?.downloadProgress ?? 0.0,
                sizeInBytes: sizeInBytes,
                downloadSpeed: downloadSpeed,
                estimatedTimeRemaining: estimatedTimeRemaining,
                isActive: false,
                onPause: {
                    // Not used for paused state
                },
                onResume: handleResume,
                onCancel: handleCancel
            )

        case .downloaded:
            // Check runtime state for actual status
            if let model = currentModel {
                switch model.runtimeState {
                case .loading:
                    ModelActionButtonLoadingView(
                        progress: 0.0,
                        sizeInBytes: sizeInBytes
                    )

                case .generating:
                    generatingView

                case .error:
                    errorView()

                case .loaded, .notLoaded:
                    deleteButton

                case .none:
                    deleteButton
                }
            } else {
                deleteButton
            }
        }
    }

    // MARK: - State-Specific Views

    private var generatingView: some View {
        StateIndicator(
            icon: "brain.filled.head.profile",
            text: String(localized: "Generating", bundle: .module),
            color: .green
        )
    }

    private func errorView() -> some View {
        StateIndicator(
            icon: "exclamationmark.circle.fill",
            text: String(localized: "Error", bundle: .module),
            color: .iconAlert
        )
    }

    // MARK: - Action Buttons

    private var downloadButton: some View {
        Button {
            setShowDownloadConfirmation(true)
        } label: {
            Label {
                Text("Download", bundle: .module)
            } icon: {
                Image(systemName: "arrow.down.circle")
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.borderless)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            setShowDeleteConfirmation(true)
        } label: {
            Label {
                Text("Delete", bundle: .module)
            } icon: {
                Image(systemName: "trash")
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Action Handlers

    private func handleDownload() {
        Self.logger.info("📥 Download requested")
        Task {
            await performDownload()
        }
    }

    private func handleDelete() {
        Self.logger.info("🗑️ Delete requested")
        Task {
            await performDelete()
        }
    }

    private func handlePause() {
        Self.logger.info("Pause requested")
        Task {
            await performPause()
        }
    }

    private func handleResume() {
        Self.logger.info("▶️ Resume requested")
        Task {
            await performResume()
        }
    }

    private func handleCancel() {
        Self.logger.info("Cancel requested")
        Task {
            await performCancel()
        }
    }

    // MARK: - Action Implementation

    private func performDownload() async {
        guard let discoveredModel else {
            Self.logger.warning("performDownload called without discovered model")
            return
        }

        Self.logger.info("Saving model: \(discoveredModel.name)")

        if let modelId = await modelActionsValue.save(discoveredModel) {
            Self.logger.info("Model saved with ID: \(modelId)")
            setTrackedModelId(modelId)

            Self.logger.info("📥 Starting download for model: \(modelId)")
            await modelActionsValue.download(modelId: modelId)
        } else {
            Self.logger.error("Failed to save model: \(discoveredModel.name)")
        }
    }

    private func performDelete() async {
        guard let model = currentModel else {
            Self.logger.warning("performDelete called without current model")
            return
        }

        Self.logger.info("🗑️ Deleting model: \(model.id)")
        await modelActionsValue.delete(modelId: model.id)
        Self.logger.info("Model deleted: \(model.id)")

        setShowDeleteConfirmation(false)

        // Keep the trackedModelId even after deletion.
        // This allows re-downloading the same model without creating a new entry.
        Self.logger.debug("🔗 Keeping tracked model ID: \(model.id) for potential re-download")
    }

    private func performPause() async {
        guard let model = currentModel else {
            Self.logger.warning("performPause called without current model")
            return
        }

        Self.logger.info("Pausing download for model: \(model.id)")
        await modelActionsValue.pauseDownload(modelId: model.id)
        Self.logger.info("Download paused for model: \(model.id)")
    }

    private func performResume() async {
        if let model = currentModel {
            Self.logger.info("▶️ Resuming download for model: \(model.id)")
            await modelActionsValue.resumeDownload(modelId: model.id)
            Self.logger.info("Download resumed for model: \(model.id)")
        } else if discoveredModel != nil {
            Self.logger.info("No model exists yet, initiating download for discovered model")
            await performDownload()
        } else {
            Self.logger.warning("performResume called without model or discovered model")
        }
    }

    private func performCancel() async {
        guard let model = currentModel else {
            Self.logger.warning("performCancel called without current model")
            return
        }

        Self.logger.info("Cancelling download for model: \(model.id)")
        await modelActionsValue.cancelDownload(modelId: model.id)
        Self.logger.info("Download cancelled for model: \(model.id)")
    }

    // MARK: - Computed Helpers

    private var modelSize: String {
        let bytes: UInt64 = sizeInBytes
        return ByteCountFormatter.string(
            fromByteCount: Int64(bytes),
            countStyle: .file
        )
    }

    private var sizeInBytes: UInt64 {
        if let model = currentModel {
            return model.size
        }
        if let discoveredModel {
            return UInt64(discoveredModel.totalSize)
        }
        return 0
    }
}
