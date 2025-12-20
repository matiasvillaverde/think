import Abstractions
import Foundation

/// Protocol for managing AI model files and directories
/// All operations use HuggingFace repository IDs (e.g., "mlx-community/Qwen3-0.6B-4bit") as identifiers
public protocol ModelFileManagerProtocol: Sendable {
    /// Get the directory for a specific repository ID
    nonisolated func modelDirectory(for repositoryId: String, backend: SendableModel.Backend) -> URL

    /// List all downloaded models
    func listDownloadedModels() async throws -> [ModelInfo]

    /// Check if a model exists by repository ID
    func modelExists(repositoryId: String) async -> Bool

    /// Delete a model and all its files by repository ID
    func deleteModel(repositoryId: String) async throws

    /// Move model files from temporary location to final location
    func moveModel(from sourceURL: URL, to destinationURL: URL) async throws

    /// Get the total size of a model by repository ID
    func getModelSize(repositoryId: String) async -> Int64?

    /// Check if there's enough disk space for a download
    func hasEnoughSpace(for size: Int64) async -> Bool

    /// Get temporary directory for downloads by repository ID
    nonisolated func temporaryDirectory(for repositoryId: String) -> URL

    /// Finalize download by moving from temp to final location
    func finalizeDownload(
        repositoryId: String,
        name: String,
        backend: SendableModel.Backend,
        from tempURL: URL,
        totalSize: Int64
    ) async throws -> ModelInfo

    /// Clean up incomplete downloads
    func cleanupIncompleteDownloads() async throws

    /// Get available disk space
    func availableDiskSpace() async -> Int64?
}
