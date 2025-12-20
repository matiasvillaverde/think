import Foundation

/// Current status of a background download
public struct BackgroundDownloadStatus: Sendable {
    /// Handle for this download
    public let handle: BackgroundDownloadHandle

    /// Current download state
    public let state: DownloadState

    /// Progress as fraction (0.0 to 1.0)
    public let progress: Double

    /// Error if download failed
    public let error: Error?

    /// Estimated time remaining (nil if unknown)
    public let estimatedTimeRemaining: TimeInterval?

    public init(
        handle: BackgroundDownloadHandle,
        state: DownloadState,
        progress: Double,
        error: Error? = nil,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.handle = handle
        self.state = state
        self.progress = progress
        self.error = error
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}
