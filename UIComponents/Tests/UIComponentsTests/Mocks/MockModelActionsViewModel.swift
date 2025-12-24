import Foundation
import Testing

@testable import Abstractions
@testable import Database

/// Mock implementation of ModelDownloaderViewModeling for testing
@MainActor
internal final class MockModelActionsViewModel: ModelDownloaderViewModeling {
    var modelToReturn: Model?
    var downloadCalled: Bool = false
    var downloadedModel: DiscoveredModel?
    var downloadModelIdCalled: Bool = false
    var downloadedModelId: UUID?
    var cancelDownloadCalled: Bool = false
    var cancelledModel: Model?
    var cancelDownloadIdCalled: Bool = false
    var cancelledModelId: UUID?
    var pauseDownloadCalled: Bool = false
    var pausedModel: Model?
    var pauseDownloadIdCalled: Bool = false
    var pausedModelId: UUID?
    var resumeDownloadCalled: Bool = false
    var resumedModel: Model?
    var resumeDownloadIdCalled: Bool = false
    var resumedModelId: UUID?
    var deleteModelCalled: Bool = false
    var deletedModel: Model?
    var deleteModelIdCalled: Bool = false
    var deletedModelId: UUID?

    func model(for _: DiscoveredModel) -> Model? {
        modelToReturn
    }

    func download(_ discoveredModel: DiscoveredModel) async {
        downloadCalled = true
        downloadedModel = discoveredModel
        await Task.yield()
    }

    func download(modelId: UUID) async {
        downloadModelIdCalled = true
        downloadedModelId = modelId
        await Task.yield()
    }

    func cancelDownload(for model: Model) async {
        cancelDownloadCalled = true
        cancelledModel = model
        await Task.yield()
    }

    func cancelDownload(modelId: UUID) async {
        cancelDownloadIdCalled = true
        cancelledModelId = modelId
        await Task.yield()
    }

    func pauseDownload(for model: Model) async {
        pauseDownloadCalled = true
        pausedModel = model
        await Task.yield()
    }

    func pauseDownload(modelId: UUID) async {
        pauseDownloadIdCalled = true
        pausedModelId = modelId
        await Task.yield()
    }

    func resumeDownload(for model: Model) async {
        resumeDownloadCalled = true
        resumedModel = model
        await Task.yield()
    }

    func resumeDownload(modelId: UUID) async {
        resumeDownloadIdCalled = true
        resumedModelId = modelId
        await Task.yield()
    }

    func deleteModel(_ model: Model) async {
        deleteModelCalled = true
        deletedModel = model
        await Task.yield()
    }

    deinit {
        // Required by swiftlint
    }

    // MARK: - ModelDownloaderViewModeling Protocol Requirements

    func save(_: DiscoveredModel) async -> UUID? {
        // For tests, just return a UUID
        await Task.yield()
        return UUID()
    }

    func delete(modelId _: UUID) async {
        // No-op for tests
        await Task.yield()
    }

    func createModelEntry(for _: DiscoveredModel) async -> UUID? {
        await Task.yield()
        return UUID()
    }

    func addLocalModel(_ model: LocalModelImport) async -> UUID? {
        await Task.yield()
        _ = model
        return UUID()
    }

    func handleBackgroundDownloadCompletion(
        identifier _: String,
        completionHandler: @Sendable () -> Void
    ) async {
        await Task.yield()
        completionHandler()
    }

    func resumeBackgroundDownloads() async {
        // No-op for tests
        await Task.yield()
    }

    func requestNotificationPermission() async -> Bool {
        // For tests, return true by default
        await Task.yield()
        return true
    }
}
