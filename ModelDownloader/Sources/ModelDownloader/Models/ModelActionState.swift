import Foundation

/// Represents the possible UI actions for a model
public enum ModelAction: String, Codable, Sendable {
    case download = "download"
    case pause = "pause"
    case resume = "resume"
    case cancel = "cancel"
    case retry = "retry"
    case open = "open"
    case delete = "delete"
}

/// Unified state for model UI interactions
///
/// This enum combines download and availability states to provide
/// a simplified state machine for UI components like ModelActionButton.
public enum ModelActionState: Codable, Equatable, Sendable {
    /// Model is available for download
    case available

    /// Model is actively downloading with progress
    case downloading(progress: Double)

    /// Model download is paused with progress
    case paused(progress: Double)

    /// Model is loading into memory with progress
    case loading(progress: Double)

    /// Model is ready for use
    case ready

    /// Model encountered an error
    case error(String)

    /// Default initializer returns available
    public init() {
        self = .available
    }

    /// Primary action available in this state
    public var primaryAction: ModelAction? {
        switch self {
        case .available:
            return .download

        case .downloading:
            return .pause

        case .paused:
            return .resume

        case .loading:
            return nil // No primary action while loading

        case .ready:
            return .open

        case .error:
            return .retry
        }
    }

    /// Secondary action available in this state
    public var secondaryAction: ModelAction? {
        switch self {
        case .available:
            return nil

        case .downloading, .paused:
            return .cancel

        case .loading:
            return .cancel

        case .ready:
            return .delete

        case .error:
            return .cancel
        }
    }

    /// Whether the model is in an active state (downloading or loading)
    public var isActive: Bool {
        switch self {
        case .downloading, .loading:
            return true

        default:
            return false
        }
    }

    /// Human-readable label for the current state
    public var actionLabel: String {
        switch self {
        case .available:
            return "Download"

        case .downloading(let progress):
            return "Downloading \(Int(progress * 100))%"

        case .paused(let progress):
            return "Paused \(Int(progress * 100))%"

        case .loading(let progress):
            return "Loading \(Int(progress * 100))%"

        case .ready:
            return "Ready"

        case .error:
            return "Error"
        }
    }

    /// Validates if a transition from one state to another is allowed
    public static func isValidTransition(from: Self, to toState: Self) -> Bool {
        switch (from, toState) {
        // Can start downloading from available
        case (.available, .downloading):
            return true

        // Can pause/resume downloads
        case (.downloading, .paused):
            return true

        case (.paused, .downloading):
            return true

        // Can cancel from downloading/paused to available
        case (.downloading, .available), (.paused, .available):
            return true

        // Can start loading after download completes
        case (.downloading, .loading):
            return true

        // Can become ready from loading
        case (.loading, .ready):
            return true

        // Can delete from ready to available
        case (.ready, .available):
            return true

        // Can transition to error from any state
        case (_, .error):
            return true

        // Can retry from error to available
        case (.error, .available):
            return true

        // All other transitions are invalid
        default:
            return false
        }
    }

    /// Creates ModelActionState from separate download and availability states
    public static func from(download: DownloadStatus, availability: ModelAvailability) -> Self {
        // Check for errors first
        if case .failed(let error) = download {
            return .error(error)
        }
        if case .error(let message) = availability {
            return .error(message)
        }

        // Then check download status
        switch download {
        case .notStarted:
            return .available

        case .downloading(let progress):
            return .downloading(progress: progress)

        case .paused(let progress):
            return .paused(progress: progress)

        case .completed:
            // If downloaded, check availability
            switch availability {
            case .notReady:
                return .loading(progress: 0.0)

            case .loading(let progress):
                return .loading(progress: progress)

            case .ready, .generating:
                return .ready

            case .error(let message):
                return .error(message)
            }

        case .failed(let error):
            return .error(error)
        }
    }
}
