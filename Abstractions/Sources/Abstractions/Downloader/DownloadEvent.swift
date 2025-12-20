import Foundation

/// Events emitted during model download via AsyncThrowingStream
public enum DownloadEvent: Sendable {
    /// Progress update during download
    case progress(DownloadProgress)

    /// Download completed successfully
    case completed(ModelInfo)
}
