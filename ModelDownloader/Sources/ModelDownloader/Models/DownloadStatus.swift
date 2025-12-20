import Foundation

/// Represents the download status of a model
///
/// This enum tracks the various states a model can be in during the download process,
/// providing clear separation between download concerns and model availability.
public enum DownloadStatus: Codable, Equatable, Sendable {
    /// Model has not been downloaded yet
    case notStarted

    /// Model is actively being downloaded with progress
    case downloading(progress: Double)

    /// Model download is paused with current progress
    case paused(progress: Double)

    /// Model download completed successfully
    case completed

    /// Model download failed with an error
    case failed(error: String)

    /// Default initializer returns notStarted
    public init() {
        self = .notStarted
    }

    /// Checks if the model is currently downloading
    public var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }

    /// Checks if the download is paused
    public var isPaused: Bool {
        if case .paused = self {
            return true
        }
        return false
    }

    /// Checks if the download is completed
    public var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    /// Returns the current download progress (0.0 to 1.0)
    public var progress: Double {
        switch self {
        case .notStarted:
            return 0.0

        case .downloading(let progress), .paused(let progress):
            return progress

        case .completed:
            return 1.0

        case .failed:
            return 0.0
        }
    }

    /// Validates if a transition from one status to another is allowed
    public static func isValidTransition(from: Self, to toState: Self) -> Bool {
        switch (from, toState) {
        // Can start downloading from notStarted
        case (.notStarted, .downloading):
            return true

        // Can pause/resume active downloads
        case (.downloading, .paused):
            return true

        case (.paused, .downloading):
            return true

        // Can complete from downloading
        case (.downloading, .completed):
            return true

        // Can fail from any active state
        case (.notStarted, .failed),
             (.downloading, .failed),
             (.paused, .failed):
            return true

        // All other transitions are invalid
        default:
            return false
        }
    }
}
