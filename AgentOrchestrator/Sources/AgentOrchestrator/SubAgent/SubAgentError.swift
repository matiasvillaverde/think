import Foundation

/// Errors specific to sub-agent operations
public enum SubAgentError: Error, LocalizedError {
    case cancelled
    case executionFailed(String)
    case requestNotFound
    case timeout

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sub-agent was cancelled"

        case .executionFailed(let reason):
            return "Sub-agent execution failed: \(reason)"

        case .requestNotFound:
            return "Sub-agent request not found"

        case .timeout:
            return "Sub-agent execution timed out"
        }
    }
}
