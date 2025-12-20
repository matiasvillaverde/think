import Abstractions
import Foundation
import OSLog

/// Decision handler that triggers memory flush when context limit is approaching
internal struct MemoryFlushDecisionHandler: DecisionHandler {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "MemoryFlushDecisionHandler"
    )

    private let config: AgentOrchestratorConfiguration.Compaction
    internal let next: DecisionHandler?

    internal init(
        config: AgentOrchestratorConfiguration.Compaction = .init(),
        next: DecisionHandler? = nil
    ) {
        self.config = config
        self.next = next
    }

    internal func decide(_ state: GenerationState) async throws -> GenerationDecision? {
        // Skip if auto-flush is disabled
        guard config.enableAutoFlush else {
            return try await next?.decide(state)
        }

        // Skip if memory flush was already performed this generation
        guard !state.hasPerformedMemoryFlush else {
            return try await next?.decide(state)
        }

        // Check if context utilization exceeds soft threshold
        let utilization: Double = state.contextUtilization
        if utilization >= config.softThresholdPercent {
            Self.logger.info(
                "Context utilization at \(Int(utilization * 100))%, triggering memory flush prompt"
            )
            return .continueWithNewPrompt(config.flushPrompt)
        }

        // Pass to next handler
        return try await next?.decide(state)
    }
}
