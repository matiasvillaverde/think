import Abstractions
import Database
import Foundation
import OSLog

/// Default view model implementation for model actions functionality in previews
internal final class PreviewModelActionsViewModel: ModelDownloaderViewModeling {
    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "PreviewViewModels"
    )

    private enum PreviewConstants {
        static let stateModuloFactor: Int = 5
        static let downloadActiveProgress: Double = 0.45
        static let downloadPausedProgress: Double = 0.75
        static let state0: Int = 0
        static let state1: Int = 1
        static let state2: Int = 2
        static let state3: Int = 3
        static let state4: Int = 4
    }

    // Model-based methods not in protocol but provided for UI components
    @MainActor
    func model(for discoveredModel: DiscoveredModel) -> Model? {
        logger.warning("Default view model - model called for: \(discoveredModel.name)")
        // Return nil to simulate no local model exists
        return nil
    }

    @MainActor
    func download(modelId: UUID) async {
        await Task.yield()
        logger.warning("Default view model - download called for model ID: \(modelId)")
    }

    // Model-based methods not in protocol but provided for UI components
    @MainActor
    func cancelDownload(for model: Model) async {
        await Task.yield()
        logger.warning("Default view model - cancelDownload called for: \(model.name)")
    }

    @MainActor
    func cancelDownload(modelId: UUID) async {
        await Task.yield()
        logger.warning("Default view model - cancelDownload called for model ID: \(modelId)")
    }

    // Model-based methods not in protocol but provided for UI components
    @MainActor
    func pauseDownload(for model: Model) async {
        await Task.yield()
        logger.warning("Default view model - pauseDownload called for: \(model.name)")
    }

    @MainActor
    func pauseDownload(modelId: UUID) async {
        await Task.yield()
        logger.warning("Default view model - pauseDownload called for model ID: \(modelId)")
    }

    // Model-based methods not in protocol but provided for UI components
    @MainActor
    func resumeDownload(for model: Model) async {
        await Task.yield()
        logger.warning("Default view model - resumeDownload called for: \(model.name)")
    }

    @MainActor
    func resumeDownload(modelId: UUID) async {
        await Task.yield()
        logger.warning("Default view model - resumeDownload called for model ID: \(modelId)")
    }

    // Model-based methods not in protocol but provided for UI components
    @MainActor
    func deleteModel(_ model: Model) async {
        await Task.yield()
        logger.warning("Default view model - deleteModel called for: \(model.name)")
    }

    deinit {
        logger.info("PreviewModelActionsViewModel deallocated")
    }

    // MARK: - ModelDownloaderViewModeling Protocol Requirements

    func save(_ discovery: DiscoveredModel) async -> UUID? {
        await MainActor.run {
            logger.warning("Default view model - save called for: \(discovery.name)")
        }
        return UUID()
    }

    func delete(modelId: UUID) async {
        await MainActor.run {
            logger.warning("Default view model - delete called for model ID: \(modelId)")
        }
    }

    func createModelEntry(for discovery: DiscoveredModel) async -> UUID? {
        await MainActor.run {
            logger.warning("Default view model - createModelEntry called for: \(discovery.name)")
        }
        return UUID()
    }

    func addLocalModel(_ model: LocalModelImport) async -> UUID? {
        await MainActor.run {
            logger.warning(
                "Default view model - addLocalModel called for: \(model.name, privacy: .public)"
            )
            logger.warning("Default VM backend: \(model.backend.rawValue, privacy: .public)")
        }
        _ = model
        return UUID()
    }

    func handleBackgroundDownloadCompletion(
        identifier _: String,
        completionHandler: @Sendable () -> Void
    ) async {
        await MainActor.run {
            logger.warning("Default view model - handleBackgroundDownloadCompletion called")
        }
        completionHandler()
    }

    func resumeBackgroundDownloads() async {
        await MainActor.run {
            logger.warning("Default view model - resumeBackgroundDownloads called")
        }
    }

    func requestNotificationPermission() async -> Bool {
        await MainActor.run {
            logger.warning("Default view model - requestNotificationPermission called")
        }
        return true
    }
}
