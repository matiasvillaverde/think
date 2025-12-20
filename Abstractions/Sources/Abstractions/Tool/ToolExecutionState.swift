import Foundation

/// Tool execution lifecycle (State Pattern)
public enum ToolExecutionState: String, Sendable, Codable, CaseIterable {
    case parsing      // LLM is still outputting
    case pending      // Ready to execute
    case executing    // Currently running
    case completed    // Successfully finished
    case failed       // Error occurred

    /// Human-readable description
    public var description: String {
        switch self {
        case .parsing:
            return "Parsing tool call"
        case .pending:
            return "Ready to execute"
        case .executing:
            return "Executing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    /// Check if this is a terminal state
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }

    /// Check if the tool can be executed in this state
    public var canExecute: Bool {
        self == .pending
    }
}
