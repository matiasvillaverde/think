import Foundation

public enum ToolIdentifier: String, CaseIterable, Hashable, Sendable {
    case imageGeneration = "Generate an image"
    case browser = "Browser"
    case python = "Python"
    case functions = "Functions"
    case healthKit = "Health Data"
    case weather = "Weather"
    case duckduckgo = "DuckDuckGo Search"
    case braveSearch = "Brave Search"
    case memory = "Memory"
    case subAgent = "Sub-Agent"
    case workspace = "Workspace Files"
    case cron = "Cron"
    case canvas = "Canvas"
    case nodes = "Nodes"
}

extension ToolIdentifier {
    /// Standard tool name used by tooling implementations
    public var toolName: String {
        switch self {
        case .browser: return "browser.search"
        case .python: return "python_exec"
        case .functions: return "functions"
        case .healthKit: return "health_data"
        case .weather: return "weather"
        case .duckduckgo: return "duckduckgo_search"
        case .braveSearch: return "brave_search"
        case .imageGeneration: return "image_generation"
        case .memory: return "memory"
        case .subAgent: return "sub_agent"
        case .workspace: return "workspace"
        case .cron: return "cron"
        case .canvas: return "canvas"
        case .nodes: return "nodes"
        }
    }

    /// Create ToolIdentifier from tool name
    public static func from(toolName: String) -> ToolIdentifier? {
        ToolIdentifier.allCases.first { $0.toolName == toolName }
    }
}
