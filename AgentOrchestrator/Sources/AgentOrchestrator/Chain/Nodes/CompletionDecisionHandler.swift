import OSLog

internal struct CompletionDecisionHandler: DecisionHandler {
    private static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "CompletionDecisionHandler"
    )

    internal let next: DecisionHandler?

    internal func decide(_ state: GenerationState) async throws -> GenerationDecision? {
        Self.logger.debug("Completion check - hasOutput: \(state.latestOutput != nil)")
        Self.logger.debug("Pending tools count: \(state.pendingToolCalls.count)")

        if let output = state.latestOutput {
            #if DEBUG
            // Get the final channel content for preview
            let textPreview: String = output.channels.first { $0.type == .final }?.content ?? ""
            Self.logger.debug("Latest output preview: '\(String(textPreview.prefix(100)), privacy: .public)'")
            #endif
            let textLength: Int = output.channels.first { $0.type == .final }?.content.count ?? 0
            Self.logger.debug("Latest output length: \(textLength)")
        }

        // Complete if no pending tools and have output
        if state.latestOutput != nil,
            state.pendingToolCalls.isEmpty {
            Self.logger.info("Generation complete after \(state.iterationCount) iterations")
            return .complete
        }

        Self.logger.debug("Generation not complete - continuing chain")
        return try await next?.decide(state)
    }
}
