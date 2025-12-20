import Foundation

/// Errors that can occur during tool execution
public enum ToolExecutionError: Error, LocalizedError, Sendable {
    case invalidStateTransition(from: ToolExecutionState, to: ToolExecutionState)
    case cannotCompleteInState(ToolExecutionState)
    case toolNotFound(String)
    case invalidArguments(String)
    case executionFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case let .invalidStateTransition(from, to):
            return "Invalid state transition from \(from) to \(to)"
        case .cannotCompleteInState(let state):
            return "Cannot complete tool execution in state: \(state)"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .invalidArguments(let details):
            return "Invalid tool arguments: \(details)"
        case .executionFailed(let reason):
            return "Tool execution failed: \(reason)"
        case .timeout:
            return "Tool execution timed out"
        }
    }
}
