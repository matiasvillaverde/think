import Foundation

/// Represents possible errors that can occur during view model operations
public enum ViewModelError: LocalizedError, Hashable, Sendable {
    /// Indicates the specified model type is not supported by the current implementation
    case modelNotSupported(SendableModel.ModelType)
    /// Indicates an attempt to start a download when one is already in progress
    case downloadAlreadyInProgress
    /// Indicates an attempt to interact with a download that is not currently running
    case downloadNotInProgress

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .modelNotSupported(let modelType):
            return "Model type '\(modelType)' is not supported"
        case .downloadAlreadyInProgress:
            return "Cannot start download - a download is already in progress"
        case .downloadNotInProgress:
            return "Cannot interact with download - no download is currently in progress"
        }
    }

    public var failureReason: String? {
        switch self {
        case .modelNotSupported(let modelType):
            return "The application does not support operations with model type: \(modelType)"
        case .downloadAlreadyInProgress:
            return "A download operation is currently active and must be completed or cancelled first"
        case .downloadNotInProgress:
            return "No active download operation was found"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelNotSupported:
            return "Please use a supported model type or update to the latest version"
        case .downloadAlreadyInProgress:
            return "Wait for the current download to complete or cancel it before starting a new one"
        case .downloadNotInProgress:
            return "Start a download before attempting to interact with it"
        }
    }
}

// MARK: - CustomDebugStringConvertible Conformance

extension ViewModelError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .modelNotSupported(let modelType):
            return "ViewModelError.modelNotSupported(\(modelType))"
        case .downloadAlreadyInProgress:
            return "ViewModelError.downloadAlreadyInProgress"
        case .downloadNotInProgress:
            return "ViewModelError.downloadNotInProgress"
        }
    }
}
