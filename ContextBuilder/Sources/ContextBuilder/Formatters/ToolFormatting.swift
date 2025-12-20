import Abstractions
import Foundation

/// Protocol for formatters that need tool formatting
internal protocol ToolFormatting {
    func formatTools(_ definitions: [ToolDefinition]) -> String
}

/// Default implementation for tool formatting
extension ToolFormatting {
    func formatTools(_ definitions: [ToolDefinition]) -> String {
        // Format tool definitions
        guard !definitions.isEmpty else {
            return ""
        }

        // Default implementation formats tools as JSON-like structure
        let toolDescriptions: [String] = definitions.map { tool in
            """
            Tool: \(tool.name)
            Description: \(tool.description)
            Schema: \(tool.schema)
            """
        }

        return toolDescriptions.joined(separator: "\n\n")
    }
}
