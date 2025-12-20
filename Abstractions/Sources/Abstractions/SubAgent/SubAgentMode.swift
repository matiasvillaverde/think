import Foundation

/// Execution mode for sub-agents
public enum SubAgentMode: String, Sendable, Codable, Equatable {
    /// Run independently, notify on completion
    case background
    /// Run with others, aggregate results
    case parallel
    /// Wait for completion before continuing
    case sequential
}
