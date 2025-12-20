import Foundation

/// Tool definition repository (Registry Pattern)
public protocol ToolRepository: Sendable {
    func definition(for name: String) async -> ToolDefinition?
    func allDefinitions() async -> [ToolDefinition]
    func register(_ definition: ToolDefinition) async
    func unregister(name: String) async
}
