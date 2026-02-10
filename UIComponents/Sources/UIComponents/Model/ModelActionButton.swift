import Abstractions
import Database
import OSLog
import SwiftData
import SwiftUI

// MARK: - ModelActionButton

/// Smart button component that handles model state and actions.
///
/// This component accepts either a `Model` or a `DiscoveredModel` and provides
/// appropriate UI and actions based on the current state.
internal struct ModelActionButton: View {
    // MARK: - Input Types

    /// Represents the input to the button: either an existing model or a discovered one.
    public enum Input {
        case existing(Model)
        case discovered(DiscoveredModel)
    }

    // MARK: - Properties

    static let logger: Logger = .init(
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

    /// The current model, either from `input` or tracked after save.
    var currentModel: Model? {
        switch input {
        case let .existing(model):
            // For existing models, always use the latest from database.
            return models.first { $0.id == model.id }

        case .discovered:
            // For discovered models, check if we've saved it.
            guard let trackedModelId else {
                return nil
            }
            return models.first { $0.id == trackedModelId }
        }
    }

    /// The discovered model if input is discovered type.
    var discoveredModel: DiscoveredModel? {
        switch input {
        case .existing:
            nil

        case let .discovered(model):
            model
        }
    }

    /// Determines if we should show download action.
    var shouldShowDownload: Bool {
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

    // MARK: - Cross-File Helpers

    var showDownloadConfirmationBinding: Binding<Bool> {
        $showDownloadConfirmation
    }

    var showDeleteConfirmationBinding: Binding<Bool> {
        $showDeleteConfirmation
    }

    func setShowDownloadConfirmation(_ value: Bool) {
        showDownloadConfirmation = value
    }

    func setShowDeleteConfirmation(_ value: Bool) {
        showDeleteConfirmation = value
    }

    func setTrackedModelId(_ id: UUID?) {
        trackedModelId = id
    }

    var downloadSpeed: Double? {
        downloadMetrics.downloadSpeed
    }

    var estimatedTimeRemaining: TimeInterval? {
        downloadMetrics.estimatedTimeRemaining
    }

    func updateDownloadMetrics(newProgress: Double, modelSize: UInt64) {
        downloadMetrics.updateMetrics(newProgress: newProgress, modelSize: modelSize)
    }

    var modelActionsValue: ModelDownloaderViewModeling {
        modelActions
    }
}
