import Foundation

/// Result of tool validation indicating availability status
public enum ToolValidationResult: Sendable {
    /// Tool is available and ready to use
    case available
    /// Tool requires a model download before use
    case requiresDownload(modelId: UUID, size: UInt64)
    /// Insufficient memory to run the tool
    case insufficientMemory(required: UInt64, available: UInt64)
    /// Tool is not supported on this platform
    case notSupported
}

public extension ToolValidationResult {
    /// Indicates whether the tool is immediately available for use
    var isAvailable: Bool {
        switch self {
        case .available:
            return true
        default:
            return false
        }
    }

    /// Indicates whether the tool requires a download before use
    var requiresDownload: Bool {
        switch self {
        case .requiresDownload:
            return true
        default:
            return false
        }
    }
}
