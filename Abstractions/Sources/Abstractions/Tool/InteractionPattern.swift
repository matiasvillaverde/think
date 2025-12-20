import Foundation

/// Defines how a tool interacts with other tools and the system
public enum InteractionPattern: String, Codable, Sendable {
    /// Tool can be used independently without other tools
    case single = "single"

    /// Tool can be chained with other tools in sequence
    case sequential = "sequential"

    /// Tool requires context from previous tool calls
    case requiresContext = "requires_context"
}
