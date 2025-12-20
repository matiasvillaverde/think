import Foundation

/// Type alias for HuggingFace repository location (e.g., "mlx-community/qwen")
public typealias ModelLocation = String

/// Protocol for downloading AI models from HuggingFace Hub
///
/// This protocol defines the interface for downloading and managing AI models
/// across multiple formats (MLX, GGUF, CoreML) with support for background downloads,
/// progress tracking, and model lifecycle management.
///
/// Conforming types should implement thread-safe model download and storage operations
/// with proper error handling and progress reporting.
public protocol ModelDownloaderProtocol: Sendable {
    // MARK: - Background Downloads

    /// Download a model in the background with system-managed download
    /// 
    /// Background downloads continue even when the app is suspended or terminated.
    /// The system will notify the app when downloads complete.
    /// 
    /// - Parameters:
    ///   - sendableModel: The SendableModel to download
    ///   - options: Configuration options for the background download
    /// - Returns: AsyncThrowingStream that yields background download events
    func downloadModelInBackground(
        sendableModel: ModelLocation,
        options: BackgroundDownloadOptions
    ) -> AsyncThrowingStream<BackgroundDownloadEvent, Error>

    /// Resume any pending background downloads from previous app sessions
    /// 
    /// Call this method on app launch to reconnect with system-managed downloads
    /// that were started in previous sessions.
    /// 
    /// - Returns: Array of handles for active background downloads
    func resumeBackgroundDownloads() async throws -> [BackgroundDownloadHandle]

    /// Get current status of all background downloads
    /// 
    /// - Returns: Array of status objects for all active background downloads
    func backgroundDownloadStatus() async -> [BackgroundDownloadStatus]

    /// Cancel a specific background download
    /// 
    /// - Parameter handle: The handle of the download to cancel
    func cancelBackgroundDownload(_ handle: BackgroundDownloadHandle) async

    // MARK: - Model Management

    /// List all downloaded models
    /// 
    /// - Returns: Array of ModelInfo for all models in local storage
    func listDownloadedModels() async throws -> [ModelInfo]

    /// Check if a model exists in local storage
    /// 
    /// - Parameter modelId: UUID of the model to check
    /// - Returns: True if the model exists locally
    func modelExists(model: ModelLocation) async -> Bool

    /// Delete a downloaded model from local storage
    /// 
    /// Removes all files associated with the model.
    /// 
    /// - Parameter modelId: UUID of the model to delete
    func deleteModel(model: ModelLocation) async throws

    /// Get the total size of a downloaded model
    /// 
    /// - Parameter modelId: UUID of the model
    /// - Returns: Total size in bytes, or nil if model not found
    func getModelSize(model: ModelLocation) async -> Int64?

    // MARK: - File System Operations

    /// Get the local directory path for a SendableModel
    /// 
    /// - Parameter sendableModel: The SendableModel to locate
    /// - Returns: URL of the model's directory, or nil if not downloaded
    func getModelLocation(for model: ModelLocation) async -> URL?

    /// Get URL for a specific file within a model's directory
    /// 
    /// - Parameters:
    ///   - sendableModel: The SendableModel containing the file
    ///   - fileName: Name of the specific file
    /// - Returns: URL of the file, or nil if not found
    func getModelFileURL(for model: ModelLocation, fileName: String) async -> URL?

    /// Get all files for a SendableModel
    /// 
    /// - Parameter sendableModel: The SendableModel to get files for
    /// - Returns: Array of file URLs for the model
    func getModelFiles(for model: ModelLocation) async -> [URL]

    /// Get ModelInfo for a SendableModel if it exists
    /// 
    /// - Parameter sendableModel: The SendableModel to get info for
    /// - Returns: ModelInfo if the model is downloaded, nil otherwise
    func getModelInfo(for model: ModelLocation) async -> ModelInfo?

    // MARK: - Validation and Utilities

    /// Validate that a model is properly downloaded and complete
    /// 
    /// Checks file integrity and completeness for the specified backend.
    /// 
    /// - Parameters:
    ///   - sendableModel: The SendableModel to validate
    ///   - backend: The backend to validate against
    /// - Returns: Validation result with any warnings
    func validateModel(_ model: ModelLocation, backend: SendableModel.Backend) async throws -> ValidationResult

    /// Get the recommended backend for a SendableModel based on its type
    /// 
    /// Uses model type and repository hints to determine optimal backend.
    /// 
    /// - Parameter sendableModel: The SendableModel to analyze
    /// - Returns: Recommended Backend
    func getRecommendedBackend(for model: ModelLocation) async -> SendableModel.Backend

    /// Get available disk space on the device
    /// 
    /// - Returns: Available space in bytes, or nil if unable to determine
    func availableDiskSpace() async -> Int64?

    /// Clean up incomplete or corrupted downloads
    /// 
    /// Removes temporary files and partial downloads.
    func cleanupIncompleteDownloads() async throws

    // MARK: - Notifications and Background Handling

    /// Request permission to send notifications for download completion
    /// 
    /// - Returns: True if permission was granted
    func requestNotificationPermission() async -> Bool

    /// Handle background download completion callback from the system
    /// 
    /// Called by the app delegate when the system completes a background download.
    /// 
    /// - Parameters:
    ///   - identifier: The background session identifier
    ///   - completionHandler: System-provided completion handler to call when done
    func handleBackgroundDownloadCompletion(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    )

    // MARK: - Download Control

    /// Cancel an active download by model ID
    /// 
    /// - Parameter modelId: The HuggingFace repository ID of the download to cancel
    func cancelDownload(for model: ModelLocation) async

    /// Pause an active download by model ID
    /// 
    /// - Parameter modelId: The UUID of the download to pause
    func pauseDownload(for model: ModelLocation) async

    /// Resume a paused download by model ID
    /// 
    /// - Parameter modelId: The UUID of the download to resume
    func resumeDownload(for model: ModelLocation) async
}
