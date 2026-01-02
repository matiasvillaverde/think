import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("MemoryFlushDecisionHandler Tests")
internal struct MemoryFlushDecisionHandlerTests {
    @Test("Hard threshold triggers context limit error")
    @MainActor
    internal func hardThresholdTriggersError() async throws {
        let config: AgentOrchestratorConfiguration.Compaction = AgentOrchestratorConfiguration.Compaction(
            softThresholdPercent: 0.80,
            hardThresholdPercent: 0.90,
            enableAutoFlush: true
        )
        let handler: MemoryFlushDecisionHandler = MemoryFlushDecisionHandler(config: config, next: nil)
        let state: GenerationState = createState(utilization: 0.95)

        let decision: GenerationDecision? = try await handler.decide(state)

        if case .error(let error)? = decision {
            #expect((error as? ModelStateCoordinatorError) == .contextLimitExceeded)
        } else {
            Issue.record("Expected contextLimitExceeded error decision")
        }
    }

    @Test("Soft threshold triggers memory flush prompt")
    @MainActor
    internal func softThresholdTriggersFlushPrompt() async throws {
        let config: AgentOrchestratorConfiguration.Compaction = AgentOrchestratorConfiguration.Compaction(
            softThresholdPercent: 0.80,
            hardThresholdPercent: 0.95,
            enableAutoFlush: true
        )
        let handler: MemoryFlushDecisionHandler = MemoryFlushDecisionHandler(config: config, next: nil)
        let state: GenerationState = createState(utilization: 0.85)

        let decision: GenerationDecision? = try await handler.decide(state)

        if case .continueWithNewPrompt(let prompt)? = decision {
            #expect(prompt == config.flushPrompt)
        } else {
            Issue.record("Expected continueWithNewPrompt decision")
        }
    }

    private func createState(utilization: Double) -> GenerationState {
        let request: GenerationRequest = GenerationRequest(
            messageId: UUID(),
            chatId: UUID(),
            model: SendableModel(
                id: UUID(),
                ramNeeded: 1_024,
                modelType: .language,
                location: "test/model",
                architecture: .llama,
                backend: .mlx,
                locationKind: .huggingFace,
            ),
            action: .textGeneration([]),
            prompt: "test"
        )
        let state: GenerationState = GenerationState(request: request)
        return state.withContextUtilization(utilization)
    }
}
