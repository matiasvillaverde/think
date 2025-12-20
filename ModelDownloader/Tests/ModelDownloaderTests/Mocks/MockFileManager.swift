import Abstractions
import Foundation
@testable import ModelDownloader

/// Mock file manager for testing
internal final class MockFileManager: ModelFileManagerProtocol, @unchecked Sendable {
    private static let defaultAvailableSpace: Int64 = 1_000_000_000 // 1GB default

    internal let modelsDirectory: URL
    internal let temporaryDirectory: URL

    private var models: [String: ModelInfo] = [:] // Changed to use repositoryId as key
    private var directories: Set<String> = []
    private var availableSpace: Int64 = MockFileManager.defaultAvailableSpace
    private(set) var downloadedFiles: [String] = []
    private(set) var movedFiles: [(from: URL, to: URL)] = []

    internal init() {
        let base: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-test-\(UUID().uuidString)")
        self.modelsDirectory = base.appendingPathComponent("models")
        self.temporaryDirectory = base.appendingPathComponent("downloads")
    }

    internal init(baseDirectory: URL) {
        self.modelsDirectory = baseDirectory.appendingPathComponent("models")
        self.temporaryDirectory = baseDirectory.appendingPathComponent("downloads")
    }

    deinit {
        // Clean up mock state
    }

    // MARK: - Test Configuration

    internal func setAvailableSpace(_ space: Int64) {
        availableSpace = space
    }

    internal func addModel(_ model: ModelInfo, repositoryId: String) {
        models[repositoryId] = model
        directories.insert(modelDirectory(for: repositoryId, backend: model.backend).path)
    }

    internal func addDownloadedFile(_ filename: String) {
        downloadedFiles.append(filename)
    }

    internal func reset() {
        models.removeAll()
        directories.removeAll()
        downloadedFiles.removeAll()
        movedFiles.removeAll()
        availableSpace = Self.defaultAvailableSpace
    }

    // MARK: - ModelFileManagerProtocol

    nonisolated internal func modelDirectory(for repositoryId: String, backend: SendableModel.Backend) -> URL {
        let safeRepoId: String = repositoryId.replacingOccurrences(of: "/", with: "_")
        return URL(fileURLWithPath: "/mock/models/\(backend.rawValue)/\(safeRepoId)")
    }

    internal func listDownloadedModels() -> [ModelInfo] {
        Array(models.values)
    }

    internal func modelExists(repositoryId: String) -> Bool {
        models[repositoryId] != nil
    }

    internal func deleteModel(repositoryId: String) {
        models.removeValue(forKey: repositoryId)

        // Remove all directories for this model
        let modelPaths: [String] = SendableModel.Backend.allCases.map { backend in
            modelDirectory(for: repositoryId, backend: backend).path
        }

        directories = directories.filter { path in
            !modelPaths.contains(path)
        }
    }

    internal func moveModel(from sourceURL: URL, to destinationURL: URL) {
        directories.insert(destinationURL.path)
        movedFiles.append((from: sourceURL, to: destinationURL))

        // Track the file as downloaded
        addDownloadedFile(sourceURL.lastPathComponent)
    }

    internal func getModelSize(repositoryId: String) -> Int64? {
        models[repositoryId]?.totalSize
    }

    internal func hasEnoughSpace(for size: Int64) -> Bool {
        let bufferMultiplier: Double = 1.2
        let requiredSpace: Int64 = Int64(Double(size) * bufferMultiplier) // 20% buffer
        return availableSpace >= requiredSpace
    }

    nonisolated internal func temporaryDirectory(for repositoryId: String) -> URL {
        let safeRepoId: String = repositoryId.replacingOccurrences(of: "/", with: "_")
        return URL(fileURLWithPath: "/mock/temp/\(safeRepoId)")
    }

    internal func finalizeDownload(
        repositoryId: String,
        name: String,
        backend: SendableModel.Backend,
        from _: URL,
        totalSize: Int64
    ) async -> ModelInfo {
        // Generate deterministic UUID from repository ID for external compatibility
        let identityService: ModelIdentityService = ModelIdentityService()
        let modelId: UUID = await identityService.generateModelId(for: repositoryId)

        let modelInfo: ModelInfo = ModelInfo(
            id: modelId,
            name: name,
            backend: backend,
            location: modelDirectory(for: repositoryId, backend: backend),
            totalSize: totalSize,
            downloadDate: Date(),
            metadata: [
                "repositoryId": repositoryId,
                "source": "huggingface",
                "downloadType": "repository-based"
            ]
        )

        models[repositoryId] = modelInfo
        directories.insert(modelInfo.location.path)

        return modelInfo
    }

    internal func cleanupIncompleteDownloads() {
        // Mock implementation - no-op
    }

    internal func availableDiskSpace() -> Int64? {
        availableSpace
    }
}
