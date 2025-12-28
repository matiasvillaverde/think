import Abstractions

internal struct ToolPartition {
    internal let allowed: [ToolRequest]
    internal let blocked: [ToolRequest]
}
