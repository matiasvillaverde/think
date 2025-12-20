import Abstractions
import Database
import OSLog
import SwiftData
import SwiftUI

// MARK: - ModelActionButton

/// Smart button component that handles model state and actions
///
/// This component accepts either a Model or a DiscoveredModel and provides
/// appropriate UI and actions based on the current state
internal struct ModelActionButton: View {
    // MARK: - Input Types

    /// Represents the input to the button - either an existing model or a discovered one
    public enum Input {
        case existing(Model)
        case discovered(DiscoveredModel)
    }

    // MARK: - Properties

    private static let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "ModelActionButton",
        category: "ModelActionButton"
    )

    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    @Query private var models: [Model]

    @State private var showDownloadConfirmation: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var trackedModelId: UUID?
    @StateObject private var downloadMetrics: DownloadMetricsTracker = .init()

    private let input: Input

    // MARK: - Computed Properties

    /// The current model, either from input or tracked after save
    private var currentModel: Model? {
        switch input {
        case let .existing(model):
            // For existing models, always use the latest from database
            return models.first { $0.id == model.id }

        case .discovered:
            // For discovered models, check if we've saved it
            guard let trackedModelId else {
                return nil
            }
            return models.first { $0.id == trackedModelId }
        }
    }

    /// The discovered model if input is discovered type
    private var discoveredModel: DiscoveredModel? {
        switch input {
        case .existing:
            nil

        case let .discovered(model):
            model
        }
    }

    /// Determines if we should show download action
    private var shouldShowDownload: Bool {
        currentModel == nil && discoveredModel != nil
    }

    // MARK: - Initialization

    internal init(model: Model) {
        input = .existing(model)
    }

    internal init(discoveredModel: DiscoveredModel) {
        input = .discovered(discoveredModel)
        Self.logger.debug("Initialized with discovered model: \(discoveredModel.id)")
    }

    // MARK: - Body

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
            showDownloadConfirmation: $showDownloadConfirmation,
            showDeleteConfirmation: $showDeleteConfirmation,
            modelSize: modelSize,
            onDownload: handleDownload,
            onDelete: handleDelete
        )
        .onChange(of: currentModel?.downloadProgress) { _, newValue in
            if let newProgress = newValue, let model = currentModel {
                downloadMetrics.updateMetrics(newProgress: newProgress, modelSize: model.size)
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
                downloadSpeed: downloadMetrics.downloadSpeed,
                estimatedTimeRemaining: downloadMetrics.estimatedTimeRemaining,
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
                downloadSpeed: downloadMetrics.downloadSpeed,
                estimatedTimeRemaining: downloadMetrics.estimatedTimeRemaining,
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
        StateIndicator(icon: "brain.filled.head.profile", text: "Generating", color: .green)
    }

    private func errorView() -> some View {
        StateIndicator(icon: "exclamationmark.circle.fill", text: "Error", color: .iconAlert)
    }

    // MARK: - Action Buttons

    private var downloadButton: some View {
        Button {
            showDownloadConfirmation = true
        } label: {
            Label("Download", systemImage: "arrow.down.circle")
        }
        .buttonStyle(.borderless)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
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

        if let modelId = await modelActions.save(discoveredModel) {
            Self.logger.info("Model saved with ID: \(modelId)")
            trackedModelId = modelId

            Self.logger.info("📥 Starting download for model: \(modelId)")
            await modelActions.download(modelId: modelId)
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
        await modelActions.delete(modelId: model.id)
        Self.logger.info("Model deleted: \(model.id)")

        showDeleteConfirmation = false

        // Keep the trackedModelId even after deletion
        // This allows re-downloading the same model without creating a new entry
        Self.logger.debug("🔗 Keeping tracked model ID: \(model.id) for potential re-download")
    }

    private func performPause() async {
        guard let model = currentModel else {
            Self.logger.warning("performPause called without current model")
            return
        }

        Self.logger.info("Pausing download for model: \(model.id)")
        await modelActions.pauseDownload(modelId: model.id)
        Self.logger.info("Download paused for model: \(model.id)")
    }

    private func performResume() async {
        if let model = currentModel {
            Self.logger.info("▶️ Resuming download for model: \(model.id)")
            await modelActions.resumeDownload(modelId: model.id)
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
        await modelActions.cancelDownload(modelId: model.id)
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
