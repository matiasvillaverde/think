import Foundation

/// Labels for tool calling functionality
internal protocol ToolCallingLabels {
    /// Label marking the start of a tool call
    var toolLabel: String { get }

    /// Label marking the end of a tool call
    var toolEndLabel: String { get }

    /// Label marking the start of a tool response
    var toolResponseLabel: String { get }

    /// Label marking the end of a tool response
    var toolResponseEndLabel: String { get }
}
