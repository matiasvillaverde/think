import Foundation

/// Represents the runtime availability of a model
///
/// This enum tracks whether a model is loaded in memory and ready for use,
/// separate from its download status.
public enum ModelAvailability: Codable, Equatable, Sendable {
    /// Model is not loaded in memory
    case notReady

    /// Model is being loaded into memory with progress
    case loading(progress: Double)

    /// Model is loaded and ready for use
    case ready

    /// Model is currently generating output
    case generating

    /// Model encountered an error during loading or generation
    case error(String)

    /// Default initializer returns notReady
    public init() {
        self = .notReady
    }

    /// Checks if the model is ready for use (includes generating state)
    public var isReady: Bool {
        switch self {
        case .ready, .generating:
            return true

        default:
            return false
        }
    }

    /// Checks if the model is currently loading
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Checks if the model is currently generating
    public var isGenerating: Bool {
        if case .generating = self {
            return true
        }
        return false
    }

    /// Checks if the model has an error
    public var hasError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// Validates if a transition from one availability to another is allowed
    public static func isValidTransition(from: Self, to toState: Self) -> Bool {
        switch (from, toState) {
        // Can start loading from notReady
        case (.notReady, .loading):
            return true

        // Can become ready from loading
        case (.loading, .ready):
            return true

        // Can start/stop generating from ready
        case (.ready, .generating):
            return true

        case (.generating, .ready):
            return true

        // Can transition to error from any state
        case (_, .error):
            return true

        // All other transitions are invalid
        default:
            return false
        }
    }
}
