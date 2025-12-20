import Foundation

/// Types of memory that can be stored in the persistent memory system
public enum MemoryType: String, Sendable, Equatable, CaseIterable, Codable {
    /// Persona definition (SOUL.md equivalent) - defines the agent's identity and behavior
    case soul = "soul"
    /// Curated long-term facts (MEMORY.md equivalent) - important persistent information
    case longTerm = "long_term"
    /// Daily append-only logs (YYYY-MM-DD.md equivalent) - contextual daily entries
    case daily = "daily"

    /// Human-readable display name for the memory type
    public var displayName: String {
        switch self {
        case .soul:
            return "Soul/Persona"
        case .longTerm:
            return "Long-term Memory"
        case .daily:
            return "Daily Log"
        }
    }

    /// Description of what this memory type is used for
    public var description: String {
        switch self {
        case .soul:
            return "Defines the agent's identity, personality, and core behavior patterns"
        case .longTerm:
            return "Stores important curated facts and information that should persist across sessions"
        case .daily:
            return "Append-only daily logs that capture contextual observations and events"
        }
    }
}
