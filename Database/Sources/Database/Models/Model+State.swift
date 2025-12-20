import Foundation

// MARK: - State
extension Model {
    /// Represents the download states of a model (persisted to disk)
    public enum State: String, Codable, Equatable, Sendable {
        /// Model is available but not yet downloaded
        case notDownloaded
        /// Model is actively being downloaded
        case downloadingActive
        /// Model download is paused
        case downloadingPaused
        /// Model is currently on device and ready to be loaded
        case downloaded

        public var isDownloaded: Bool {
            switch self {
            case .downloaded:
                return true
            default:
                return false
            }
        }

        public var isNotDownloaded: Bool {
            switch self {
            case .notDownloaded:
                return true
            default:
                return false
            }
        }

        public var isDownloading: Bool {
            switch self {
            case .downloadingActive, .downloadingPaused:
                return true
            default:
                return false
            }
        }

        public var isDownloadingActive: Bool {
            guard case .downloadingActive = self else {
                return false
            }
            return true
        }

        public var isDownloadingPaused: Bool {
            guard case .downloadingPaused = self else {
                return false
            }
            return true
        }
    }

    /// Represents possible errors that can occur with a model
    public enum ModelError: Error, Codable, Equatable {
        case downloadFailed(String)
        case preparationFailed(String)
        case invalidState
        case invalidLocation
        case invalidStateTransition
        case invalidJSON
        case missingLocation(String)
    }

    /// Defines valid state transitions for the download state
    public static func isValidTransition(from currentState: State, to newState: State) -> Bool {
        switch (currentState, newState) {
        case (.notDownloaded, .downloadingActive):
            return true
        case (.downloadingActive, .downloadingPaused):
            return true
        case (.downloadingPaused, .downloadingActive):
            return true
        case (.downloadingActive, .downloaded):
            return true
        case (.downloadingPaused, .downloaded):
            return true
        case (.downloadingActive, .notDownloaded):
            // Allow canceling download
            return true
        case (.downloadingPaused, .notDownloaded):
            // Allow canceling paused download
            return true
        case (.downloaded, .notDownloaded):
            // Allow deleting downloaded model
            return true
        default:
            return false
        }
    }

    var isDeepThinker: Bool {
        switch type {
        case .deepLanguage:
            true
        default:
            false
        }
    }

    public var isPartOfBundle: Bool {
        false  // No longer tracking bundle location
    }
}
