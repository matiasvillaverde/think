import Abstractions

internal struct ToolExecutionResult {
    internal let responses: [ToolResponse]
    internal let toolsUsed: [String]
}
