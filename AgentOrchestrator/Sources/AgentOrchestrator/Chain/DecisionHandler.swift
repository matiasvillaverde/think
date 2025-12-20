import Abstractions
import OSLog

// MARK: - Chain of Responsibility for Post-Stream Decisions
internal protocol DecisionHandler: Sendable {
    var next: DecisionHandler? { get }

    func decide(_ state: GenerationState) async throws -> GenerationDecision?
}
