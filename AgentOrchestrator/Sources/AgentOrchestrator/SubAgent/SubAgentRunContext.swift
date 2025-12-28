import Abstractions

internal struct SubAgentRunContext {
    internal let model: SendableModel
    internal let action: Action
    internal let contextConfig: ContextConfiguration
}
