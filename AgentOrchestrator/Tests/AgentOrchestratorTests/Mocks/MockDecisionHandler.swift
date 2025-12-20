@testable import AgentOrchestrator
import Foundation

internal actor MockDecisionHandler: DecisionHandler {
    internal let next: DecisionHandler?
    internal private(set) var wasCalled: Bool = false
    private let returnDecision: GenerationDecision

    internal init(returnDecision: GenerationDecision = .complete) {
        self.returnDecision = returnDecision
        self.next = nil
    }

    deinit {
        // Required by linting rules
    }

    // swiftlint:disable:next async_without_await
    internal func decide(_: GenerationState) async -> GenerationDecision? {
        wasCalled = true
        return returnDecision
    }
}
