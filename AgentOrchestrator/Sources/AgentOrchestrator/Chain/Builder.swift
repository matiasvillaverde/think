import OSLog

private let kDefaultMaxIterations: Int = 10

private let kLogger: Logger = Logger(
    subsystem: "AgentOrchestrator",
    category: "ChainBuilder"
)

internal func buildDecisionChain() -> DecisionHandler {
    kLogger.debug("Building decision chain with max iterations: \(kDefaultMaxIterations)")

    let safetyHandler: SafetyDecisionHandler = SafetyDecisionHandler(
        maxIterations: kDefaultMaxIterations,
        next: nil
    )
    let completionHandler: CompletionDecisionHandler = CompletionDecisionHandler(next: safetyHandler)
    return ToolCallDecisionHandler(next: completionHandler)
}
