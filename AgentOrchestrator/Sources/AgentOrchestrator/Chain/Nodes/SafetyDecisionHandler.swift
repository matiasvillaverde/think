import Abstractions
import OSLog

internal struct SafetyDecisionHandler: DecisionHandler {
    private static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "SafetyDecisionHandler"
    )

    internal var next: DecisionHandler?
    internal let maxIterations: Int

    internal init(maxIterations: Int, next: DecisionHandler?) {
        self.maxIterations = maxIterations
        self.next = next
    }

    internal func decide(_ state: GenerationState) async throws -> GenerationDecision? {
        if state.iterationCount >= maxIterations {
            Self.logger.warning(
                "Max iterations: \(state.iterationCount)/\(maxIterations). Stopping infinite loop"
            )
            return .error(ModelStateCoordinatorError.tooManyIterations)
        }
        // Pass to next handler in chain
        return try await next?.decide(state) ?? .complete
    }
}
