import OSLog

internal struct ToolCallDecisionHandler: DecisionHandler {
    private static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "ToolCallDecisionHandler"
    )

    internal let next: DecisionHandler?

    internal func decide(_ state: GenerationState) async throws -> GenerationDecision? {
        if let output = state.latestOutput, !output.toolRequests.isEmpty {
            Self.logger.info("Tool calls detected: \(output.toolRequests.count) tools to execute")
            return .executeTools(output.toolRequests)
        }
        return try await next?.decide(state)
    }
}
