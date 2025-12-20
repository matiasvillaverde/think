import Foundation

// swiftlint:disable line_length

/// Errors that can occur during Generator operations
///
/// This enum encapsulates the different error conditions that can occur during
/// model loading, unloading, and generation processes.
public enum GeneratorError: Error, Equatable, LocalizedError {
    /// The requested model has not been downloaded
    case modelNotDownloaded(UUID)

    /// No chat has been loaded for the current operation
    case chatIsNotLoaded

    /// A generation operation is already in progress
    case currentlyGenerating

    /// Failed to load the specified model
    case canNotLoadModel(UUID)

    /// The model was unloaded during an operation
    case modelWasUnloaded(UUID)

    /// Timed out while waiting for model to load
    case modelLoadTimeout(UUID)

    /// Invalid action for this generator
    case invalidAction(String)

    // MARK: - LocalizedError Implementation

    /// A localized message describing what error occurred
    public var errorDescription: String? {
        switch self {
        case .modelNotDownloaded(let modelId):
            return String(
                localized: "Model not downloaded (ID: \(modelId.uuidString))",
                bundle: .module,
                comment: "Error when trying to use a model that hasn't been downloaded"
            )
        case .chatIsNotLoaded:
            return  String(localized:
                "No active chat session",
                           bundle: .module,
                comment: "Error when no chat has been loaded"
            )
        case .currentlyGenerating:
            return  String(localized:
                "Generation is already in progress",
                           bundle: .module,
                comment: "Error when trying to start a new generation while one is running"
            )
        case .canNotLoadModel(let modelId):
            return  String(
                localized:
                "Failed to load model (ID: \(modelId.uuidString))",
                           bundle: .module,
                comment: "Error when model loading fails"
            )
        case .modelWasUnloaded(let modelId):
            return  String(localized:
                "Model was unexpectedly unloaded (ID: \(modelId.uuidString))",
                           bundle: .module,
                comment: "Error when a model is unloaded during an operation"
            )
        case .modelLoadTimeout(let modelId):
            return  String(localized:
                "Model loading timed out (ID: \(modelId.uuidString))",
                           bundle: .module,
                comment: "Error when model loading exceeds the timeout period"
            )
        case .invalidAction(let message):
            return String(
                localized: "Invalid action: \(message)",
                bundle: .module,
                comment: "Error when an invalid action is attempted"
            )
        }
    }

    /// A localized message describing the reason for the failure
    public var failureReason: String? {
        switch self {
        case .modelNotDownloaded(let modelId):
            return  String(localized:
                "The required model with ID \(modelId.uuidString) is not currently downloaded on this device.",
                           bundle: .module,
                comment: "Failure reason for model not downloaded error"
            )
        case .chatIsNotLoaded:
            return  String(localized:
                "No chat session has been loaded or the previous session was unloaded.",
                           bundle: .module,
                comment: "Failure reason for no active chat error"
            )
        case .currentlyGenerating:
            return  String(
                localized: "The system is currently processing another generation request and cannot handle concurrent operations.",
                           bundle: .module,
                comment: "Failure reason for concurrent generation error"
            )
        case .canNotLoadModel(let modelId):
            return  String(localized:
                "The system encountered an error while attempting to load the model with ID \(modelId.uuidString).",
                           bundle: .module,
                comment: "Failure reason for model loading error"
            )
        case .modelWasUnloaded(let modelId):
            return  String(
                localized: "The model with ID \(modelId.uuidString) was unloaded while an operation was in progress, possibly due to memory constraints.",
                bundle: .module,
                comment: "Failure reason for model unloaded error"
            )
        case .modelLoadTimeout(let modelId):
            return  String(localized:
                "Loading the model with ID \(modelId.uuidString) took longer than the maximum allowed time.",
                           bundle: .module,
                comment: "Failure reason for model loading timeout"
            )
        case .invalidAction(let message):
            return String(
                localized: "The requested action (\(message)) is not supported by this component.",
                bundle: .module,
                comment: "Failure reason for invalid action error"
            )
        }
    }

    /// A localized message describing how one might recover from the failure
    public var recoverySuggestion: String? {
        switch self {
        case .modelNotDownloaded:
            return  String(
                localized: "Please download the model from the model management screen before proceeding. Check your network connection if download fails.",
                           bundle: .module,
                comment: "Recovery suggestion for model not downloaded error"
            )
        case .chatIsNotLoaded:
            return  String(
                localized: "Load a chat session before attempting this operation. If the issue persists, try restarting the application.",
                           bundle: .module,
                comment: "Recovery suggestion for no active chat error"
            )
        case .currentlyGenerating:
            return  String(localized:
                "Wait for the current generation to complete or stop it before starting a new one.",
                           bundle: .module,
                comment: "Recovery suggestion for concurrent generation error"
            )
        case .canNotLoadModel:
            return  String(
                localized: "Try loading the model again. If the problem persists, check if the model file is corrupted and consider re-downloading it.",
                           bundle: .module,
                comment: "Recovery suggestion for model loading error"
            )
        case .modelWasUnloaded:
            return  String(localized:
                "Reload the model and try the operation again. Consider closing other applications to free memory resources.",
                           bundle: .module,
                comment: "Recovery suggestion for model unloaded error"
            )
        case .modelLoadTimeout:
            return  String(
                localized:
                "Check if your device meets the system requirements for this model. Try restarting the application and ensuring no other resource-intensive applications are running.", // swiftlint:disable:this line_length
                           bundle: .module,
                comment: "Recovery suggestion for model loading timeout"
            )
        case .invalidAction:
            return String(
                localized: "Please use the appropriate component for this action type.",
                bundle: .module,
                comment: "Recovery suggestion for invalid action error"
            )
        }
    }

    /// A localized message providing "help" text if the user requests help
    public var helpAnchor: String? {
        switch self {
        case .modelNotDownloaded:
            return "help.models.downloading"
        case .chatIsNotLoaded:
            return "help.chats.loading"
        case .currentlyGenerating:
            return "help.generation.concurrent"
        case .canNotLoadModel:
            return "help.models.loading.troubleshooting"
        case .modelWasUnloaded:
            return "help.models.memory.management"
        case .modelLoadTimeout:
            return "help.models.performance.issues"
        case .invalidAction:
            return "help.actions.routing"
        }
    }
}
