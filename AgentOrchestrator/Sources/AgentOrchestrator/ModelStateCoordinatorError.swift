import Foundation

/// Errors that can occur during model state coordination
internal enum ModelStateCoordinatorError: LocalizedError, Equatable {
    case contextLimitExceeded
    case emptyModelLocation
    case invalidModelLocationURL(String)
    case modelFileMissing(String)
    case modelLocationNotResolved(String)
    case modelNotDownloaded(String)
    case noChatLoaded
    case remoteSessionNotConfigured
    case toolingNotConfigured
    case tooManyIterations

    internal var errorDescription: String? {
        switch self {
        case .contextLimitExceeded:
            return "Context limit exceeded. Please reduce context or clear memory."

        case .emptyModelLocation:
            return "Model location is empty"

        case .invalidModelLocationURL(let location):
            return "Invalid URL for model location: \(location)"

        case .modelFileMissing(let path):
            return "Local model not found at: \(path). It may have been moved or deleted."

        case .modelLocationNotResolved(let location):
            return "Could not resolve local path for model: \(location)"

        case .modelNotDownloaded(let location):
            return "Model not found locally: \(location). Please download it first."

        case .noChatLoaded:
            return "No chat is currently loaded. Load a chat first."

        case .remoteSessionNotConfigured:
            return "Remote session is not configured. Cannot use remote models."

        case .toolingNotConfigured:
            return "Tooling is not configured. Cannot execute tool requests."

        case .tooManyIterations:
            return "Maximum iterations reached. Stopping to prevent infinite loop."
        }
    }
}
