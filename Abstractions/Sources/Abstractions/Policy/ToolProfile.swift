import Foundation

/// Predefined tool profiles that define sets of allowed tools
public enum ToolProfile: String, Sendable, Codable, CaseIterable {
    /// No tools available
    case minimal
    /// Browser only
    case basic
    /// Browser, Search, Memory tools
    case research
    /// Browser, Python execution
    case coding
    /// All available tools
    case full

    /// The tools included in this profile
    public var includedTools: Set<ToolIdentifier> {
        switch self {
        case .minimal:
            return []
        case .basic:
            return [.browser]
        case .research:
            return [.browser, .duckduckgo, .braveSearch, .memory]
        case .coding:
            return [.browser, .python, .workspace]
        case .full:
            return Set(ToolIdentifier.allCases)
        }
    }

    /// Human-readable name for the profile
    public var displayName: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .basic:
            return "Basic"
        case .research:
            return "Research"
        case .coding:
            return "Coding"
        case .full:
            return "Full Access"
        }
    }

    /// Description of what the profile allows
    public var profileDescription: String {
        switch self {
        case .minimal:
            return "No tools - text-only responses"
        case .basic:
            return "Web browsing only"
        case .research:
            return "Web search, browsing, and memory tools"
        case .coding:
            return "Web browsing and Python execution"
        case .full:
            return "All available tools"
        }
    }
}
