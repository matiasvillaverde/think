import Foundation

/// State of a download operation
public enum DownloadState: String, Sendable, Codable, CaseIterable {
    case pending = "pending"
    case downloading = "downloading"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}
