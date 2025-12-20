import Foundation

/// Events emitted during background model download via AsyncThrowingStream
public enum BackgroundDownloadEvent: Sendable {
    /// Progress update during download
    case progress(DownloadProgress)

    /// Background download handle for tracking
    case handle(BackgroundDownloadHandle)

    /// Download completed successfully
    case completed(ModelInfo)
}
