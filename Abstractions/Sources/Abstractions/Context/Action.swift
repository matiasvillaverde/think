import Foundation

public enum Action: Hashable, Sendable {
    case textGeneration(Set<ToolIdentifier>)
    case imageGeneration(Set<ToolIdentifier>)

    public var tools: Set<ToolIdentifier> {
        switch self {
        case .textGeneration(let tools), .imageGeneration(let tools):
            return tools
        }
    }

    public var isVisual: Bool {
        switch self {
        case .imageGeneration:
            return true
        default:
            return false
        }
    }

    public var isTextual: Bool {
        switch self {
        case .textGeneration:
            return true
        default:
            return false
        }
    }
}

extension Action: CaseIterable {
    public static var allCases: [Action] {
        [.textGeneration([]), .imageGeneration([])]
    }
}
