import Abstractions
import Foundation

/// Protocol for tool execution strategies (Strategy Pattern)
public protocol ToolStrategy: Sendable {
    /// The tool definition
    var definition: ToolDefinition { get }

    /// Execute the tool with the given request
    /// - Parameter request: The tool request to execute
    /// - Returns: The tool response
    func execute(request: ToolRequest) async -> ToolResponse
}
