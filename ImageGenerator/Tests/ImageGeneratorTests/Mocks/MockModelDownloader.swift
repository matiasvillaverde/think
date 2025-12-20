import Abstractions
import Foundation

/// Mock implementation of ModelDownloaderProtocol for testing
final class MockModelDownloader: ModelDownloaderProtocol {
    let modelExistsResult: Bool
    let getModelLocationResult: URL?

    init(modelExistsResult: Bool = false, getModelLocationResult: URL? = nil) {
        self.modelExistsResult = modelExistsResult
        self.getModelLocationResult = getModelLocationResult
    }

    func modelExists(model _: ModelLocation) -> Bool {
        modelExistsResult
    }

    func getModelLocation(for _: ModelLocation) -> URL? {
        getModelLocationResult
    }

    // Required protocol methods with empty implementations
    func downloadModelInBackground(
        sendableModel _: ModelLocation,
        options _: BackgroundDownloadOptions
    ) -> AsyncThrowingStream<BackgroundDownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func resumeBackgroundDownloads() -> [BackgroundDownloadHandle] { [] }
    func backgroundDownloadStatus() -> [BackgroundDownloadStatus] { [] }
    func cancelBackgroundDownload(_: BackgroundDownloadHandle) {}
    func listDownloadedModels() -> [ModelInfo] { [] }
    func deleteModel(model _: ModelLocation) {}
    func getModelSize(model _: ModelLocation) -> Int64? { nil }
    func getModelFileURL(for _: ModelLocation, fileName _: String) -> URL? { nil }
    func getModelFiles(for _: ModelLocation) -> [URL] { [] }
    func getModelInfo(for _: ModelLocation) -> ModelInfo? { nil }
    func validateModel(
        _: ModelLocation,
        backend _: SendableModel.Backend
    ) -> ValidationResult {
        ValidationResult(isValid: true, warnings: [])
    }
    func getRecommendedBackend(for _: ModelLocation) -> SendableModel.Backend { .coreml }
    func availableDiskSpace() -> Int64? { nil }
    func cleanupIncompleteDownloads() {}
    func requestNotificationPermission() -> Bool { false }
    func handleBackgroundDownloadCompletion(
        identifier _: String,
        completionHandler: @Sendable () -> Void
    ) {
        completionHandler()
    }
    func cancelDownload(for _: ModelLocation) {}
    func pauseDownload(for _: ModelLocation) {}
    func resumeDownload(for _: ModelLocation) {}
}
