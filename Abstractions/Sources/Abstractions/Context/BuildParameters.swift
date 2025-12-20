import Foundation

/// Parameters for building LLM context
public struct BuildParameters: Sendable {
    public let action: Action
    public let contextConfiguration: ContextConfiguration
    public let toolResponses: [ToolResponse]
    public let model: SendableModel

    public init(
        action: Action,
        contextConfiguration: ContextConfiguration,
        toolResponses: [ToolResponse],
        model: SendableModel
    ) {
        self.action = action
        self.contextConfiguration = contextConfiguration
        self.toolResponses = toolResponses
        self.model = model
    }
}
