import Foundation

/// Protocol for managing model downloads from discovery to persistence
///
/// This protocol defines the interface for ViewModels that handle the complete
/// model download lifecycle, from discovering models on HuggingFace to downloading
/// and persisting them locally.
///
/// All methods are non-throwing to provide a clean UI interface. Errors are
/// handled internally and communicated through notifications.
///
/// ## Example Usage
/// ```swift
/// let viewModel: ModelDownloaderViewModeling = // ... injected dependency
/// 
/// // Download a discovered model
/// let discovery = DiscoveredModel(...)
/// await viewModel.download(discovery)
/// 
/// // Cancel an active download
/// await viewModel.cancelDownload(modelId: modelId)
/// 
/// // Handle background download completion (iOS)
/// await viewModel.handleBackgroundDownloadCompletion(
///     identifier: sessionId,
///     completionHandler: { /* system handler */ }
/// )
/// ```
public protocol ModelDownloaderViewModeling: Sendable {
    // MARK: - Model Lookup

    // Note: model(for:) method is temporarily removed from protocol to avoid circular dependency
    // Implementations can still provide this method for UI components that need it

    // MARK: - Core Download Operations

    /// Saves a DiscoveredModel to the database without starting the download
    ///
    /// This method creates the model entry in the database so the UI can update immediately.
    /// Use this followed by download(modelId:) for better UI responsiveness.
    ///
    /// - Parameter discovery: The discovered model to save
    /// - Returns: The UUID of the created model, or nil if creation failed
    func save(_ discovery: DiscoveredModel) async -> UUID?

    /// Downloads a model by its ID
    ///
    ///
    /// - Parameter modelId: The UUID of the model to download
    func download(modelId: UUID) async

    /// Cancels an active download
    ///
    /// Cleans up the download state and resets the model to not downloaded.
    /// If the download is not active, this is a no-op.
    ///
    /// - Parameter modelId: The UUID of the model being downloaded
    func cancelDownload(modelId: UUID) async

    // Note: cancelDownload(for:) method is temporarily removed from protocol to avoid circular dependency
    // Implementations can still provide this method for UI components that need it

    /// Deletes a downloaded model
    ///
    /// Removes the model files from disk and updates the database state.
    ///
    /// - Parameter modelId: The UUID of the model to delete
    func delete(modelId: UUID) async

    // Note: deleteModel(_:) method taking Model parameter is temporarily removed from protocol 
    // to avoid circular dependency. Implementations can still provide this method for UI components that need it

    /// Pauses an active download
    ///
    /// Pauses the download and updates the model state to paused.
    /// If the download is not active, this is a no-op.
    ///
    /// - Parameter modelId: The UUID of the model being downloaded
    func pauseDownload(modelId: UUID) async

    // Note: pauseDownload(for:) method is temporarily removed from protocol to avoid circular dependency
    // Implementations can still provide this method for UI components that need it

    /// Resumes a paused download
    ///
    /// Resumes the download and updates the model state to active downloading.
    /// If the download is not paused, this is a no-op.
    ///
    /// - Parameter modelId: The UUID of the model to resume downloading
    func resumeDownload(modelId: UUID) async

    // Note: resumeDownload(for:) method is temporarily removed from protocol to avoid circular dependency
    // Implementations can still provide this method for UI components that need it

    // MARK: - Background Download Support

    /// Handles background download completion callback from the system
    ///
    /// Called by the app delegate when the system completes a background download.
    /// This method should reconnect with the download session and complete any
    /// pending operations.
    ///
    /// - Parameters:
    ///   - identifier: The background session identifier
    ///   - completionHandler: System-provided completion handler to call when done
    func handleBackgroundDownloadCompletion(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) async

    /// Resumes any background downloads on app launch
    ///
    /// Call this method when the app starts to reconnect with downloads that were
    /// running when the app was terminated. This ensures download progress is
    /// updated in the database and the UI reflects the current state.
    ///
    /// This method will:
    /// - Resume all persisted background downloads
    /// - Update Model entities with current progress
    /// - Re-establish active download tracking
    func resumeBackgroundDownloads() async

    // MARK: - Model Entry Creation

    /// Creates a model entry without starting download
    ///
    /// This method creates a Model entity from a DiscoveredModel but sets it to
    /// a non-downloading state (typically .notDownloaded). This allows the app
    /// to have model entries available for selection even before downloading.
    ///
    /// Used for ensuring the app always has at least one model available for
    /// proper functioning, following the principle that users should be able to
    /// select from available models before initiating downloads.
    ///
    /// - Parameter discovery: The discovered model to create an entry for
    /// - Returns: The UUID of the created model entry
    func createModelEntry(for discovery: DiscoveredModel) async -> UUID?

    // MARK: - Local Model Support

    /// Adds a locally-referenced model without downloading.
    ///
    /// The model is stored by reference (not copied), and is immediately marked as downloaded.
    ///
    /// - Parameters:
    ///   - name: Display name for the model
    ///   - backend: Backend format (.gguf or .mlx)
    ///   - type: Model type (language, visualLanguage, diffusion, etc.)
    ///   - parameters: Approximate parameter count (optional; use 1 if unknown)
    ///   - ramNeeded: Estimated RAM needed in bytes (optional; use 0 if unknown)
    ///   - size: Total size in bytes (optional; use 0 if unknown)
    ///   - locationLocal: Local filesystem path
    ///   - locationBookmark: Security-scoped bookmark data for local access
    /// - Returns: The UUID of the created model entry
    func addLocalModel(_ model: LocalModelImport) async -> UUID?

    // MARK: - Notification Support
    /// Requests notification permission for background download notifications
    ///
    /// This method should be called early in the app lifecycle to ensure users
    /// receive notifications when downloads complete in the background.
    /// The permission dialog is only shown once per app installation.
    ///
    /// - Returns: `true` if permission was granted, `false` if denied or previously denied
    func requestNotificationPermission() async -> Bool
}
