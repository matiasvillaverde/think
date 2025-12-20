import Foundation

/// Priority levels for background downloads
public enum BackgroundDownloadPriority: String, Sendable, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
}
