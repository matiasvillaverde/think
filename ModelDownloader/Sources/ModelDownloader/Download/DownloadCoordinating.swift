import Abstractions
import Foundation

/// Protocol defining the interface for coordinating model downloads
///
/// This protocol provides a high-level interface for managing the download
/// lifecycle of models, including starting, pausing, resuming, and canceling downloads.
/// All operations use HuggingFace repository IDs as identifiers.
public protocol DownloadCoordinating: Actor {
    /// Starts downloading a model
    /// - Parameter model: The model to download
    /// - Throws: ModelDownloadError if download cannot be started
    func start(model: SendableModel) async throws

    /// Pauses an active download
    /// - Parameter repositoryId: The repository ID of the model to pause
    /// - Throws: ModelDownloadError if download cannot be paused
    func pause(repositoryId: String) async throws

    /// Resumes a paused download
    /// - Parameter repositoryId: The repository ID of the model to resume
    /// - Throws: ModelDownloadError if download cannot be resumed
    func resume(repositoryId: String) async throws

    /// Cancels a download and removes associated resources
    /// - Parameter repositoryId: The repository ID of the model to cancel
    /// - Throws: ModelDownloadError if download cannot be canceled
    func cancel(repositoryId: String) async throws

    /// Gets the current download state for a model
    /// - Parameter repositoryId: The repository ID of the model
    /// - Returns: The current download status
    func state(for repositoryId: String) async -> DownloadStatus
}
