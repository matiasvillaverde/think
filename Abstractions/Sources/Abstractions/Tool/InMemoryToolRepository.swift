import Foundation

/// Default in-memory implementation
public actor InMemoryToolRepository: ToolRepository {
    private var definitions: [String: ToolDefinition] = [:]

    public init() {
        // Initialize empty repository
    }

    public func definition(for name: String) -> ToolDefinition? {
        definitions[name]
    }

    public func allDefinitions() -> [ToolDefinition] {
        Array(definitions.values)
    }

    public func register(_ definition: ToolDefinition) {
        definitions[definition.name] = definition
    }

    public func unregister(name: String) {
        definitions.removeValue(forKey: name)
    }
}
