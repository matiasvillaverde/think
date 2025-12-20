import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("AgentOrchestrator Decision Chain", .tags(.acceptance))
internal struct AgentOrchestratorChainTests {
    @Test("Safety Handler Chain of Responsibility")
    @MainActor
    internal func safetyHandlerChainOfResponsibility() async throws {
        let state: GenerationState = createStateWithTools()
        let chain: DecisionHandler = buildDecisionChain()
        let decision: GenerationDecision? = try await chain.decide(state)

        if case .executeTools(let tools) = decision {
            #expect(!tools.isEmpty, "Tools should be identified for execution")
        } else {
            Issue.record("Expected executeTools decision but got: \(String(describing: decision))")
        }
    }

    @Test("Tool Handler Executes When Output Contains Tools")
    @MainActor
    internal func toolHandlerExecutesWithTools() async throws {
        let toolHandler: ToolCallDecisionHandler = ToolCallDecisionHandler(next: nil)
        let state: GenerationState = createStateWithWeatherTool()
        let decision: GenerationDecision? = try await toolHandler.decide(state)

        if case .executeTools(let tools) = decision {
            #expect(tools.count == 1, "Should identify one tool call")
            #expect(tools.first?.name == "weather", "Should be weather tool")
        } else {
            Issue.record("Expected executeTools decision")
        }
    }

    @Test("Chain Continues After Safety Check")
    @MainActor
    internal func chainContinuesAfterSafetyCheck() async throws {
        // This test specifically checks that when iteration count is below max,
        // the safety handler should pass control to the next handler
        let state: GenerationState = createTestState(iterationCount: 2)
        let mockNext: MockDecisionHandler = MockDecisionHandler()
        let safetyHandler: SafetyDecisionHandler = SafetyDecisionHandler(
            maxIterations: 10,
            next: mockNext
        )

        let decision: GenerationDecision? = try await safetyHandler.decide(state)

        // With the fix: SafetyHandler now calls next?.decide(state)
        // Expected: Should return mockNext's decision
        #expect(
            await mockNext.wasCalled,
            "SafetyHandler should call next handler when iterations < max"
        )

        // Verify the decision matches what the mock returned
        if case .complete = decision {
            // Expected behavior - mock returns .complete
        } else {
            Issue.record("Expected .complete decision but got something else")
        }
    }

    // MARK: - Helper Methods

    private func createTestState(iterationCount: Int) -> GenerationState {
        let request: GenerationRequest = GenerationRequest(
            messageId: UUID(),
            chatId: UUID(),
            model: createSendableModel(),
            action: .textGeneration([]),
            prompt: "test"
        )

        var state: GenerationState = GenerationState(request: request)
        state.iterationCount = iterationCount
        return state
    }

    private func createSendableModel() -> SendableModel {
        SendableModel(
            id: UUID(),
            ramNeeded: 100 * 1_048_576,
            modelType: .language,
            location: "test/model",
            architecture: .llama,
            backend: .mlx
        )
    }

    private func createStateWithTools() -> GenerationState {
        let toolCall: ToolRequest = createCalculatorToolRequest()
        let output: ProcessedOutput = createCalculatorProcessedOutput(toolCall: toolCall)
        let request: GenerationRequest = createGenerationRequest(prompt: "Calculate 5 + 3")
        return GenerationState(request: request).withStreamComplete(output: output, metrics: nil)
    }

    private func createCalculatorToolRequest() -> ToolRequest {
        ToolRequest(
            name: "calculator",
            arguments: "{\"a\": 5, \"b\": 3}",
            isComplete: true
        )
    }

    private func createCalculatorProcessedOutput(toolCall: ToolRequest) -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: UUID(),
                    type: .final,
                    content: "Let me calculate.",
                    order: 0
                ),
                ChannelMessage(
                    id: UUID(),
                    type: .tool,
                    content: "calculator",
                    order: 1,
                    toolRequest: toolCall
                )
            ]
        )
    }

    private func createGenerationRequest(prompt: String) -> GenerationRequest {
        GenerationRequest(
            messageId: UUID(),
            chatId: UUID(),
            model: createSendableModel(),
            action: .textGeneration([]),
            prompt: prompt
        )
    }

    private func createStateWithWeatherTool() -> GenerationState {
        let toolRequest: ToolRequest = createWeatherToolRequest()
        let outputWithTools: ProcessedOutput = createWeatherProcessedOutput(toolRequest: toolRequest)
        return createTestState(iterationCount: 0).withStreamComplete(output: outputWithTools, metrics: nil)
    }

    private func createWeatherToolRequest() -> ToolRequest {
        ToolRequest(
            name: "weather",
            arguments: "{\"location\": \"San Francisco\"}",
            isComplete: true
        )
    }

    private func createWeatherProcessedOutput(toolRequest: ToolRequest) -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: UUID(),
                    type: .final,
                    content: "Let me check the weather.",
                    order: 0
                ),
                ChannelMessage(
                    id: UUID(),
                    type: .tool,
                    content: "weather",
                    order: 1,
                    toolRequest: toolRequest
                )
            ]
        )
    }

    @Test("Builder Chain Enforces Max Iterations Limit")
    @MainActor
    internal func testBuilderChainEnforcesMaxIterations() async throws {
        // Create a state that has reached max iterations
        let state: GenerationState = createTestState(iterationCount: 10)
        let chain: DecisionHandler = buildDecisionChain()

        let decision: GenerationDecision? = try await chain.decide(state)

        // Should return error decision when max iterations reached
        if case .error(let error) = decision {
            #expect(
                error is ModelStateCoordinatorError,
                "Should be ModelStateCoordinatorError"
            )
            if let coordError = error as? ModelStateCoordinatorError {
                #expect(
                    coordError == .tooManyIterations,
                    "Should be tooManyIterations error"
                )
            }
        } else {
            Issue.record("Expected .error decision for max iterations, got: \(String(describing: decision))")
        }
    }

    @Test("Builder Chain Allows Iterations Below Limit")
    @MainActor
    internal func testBuilderChainAllowsIterationsBelowLimit() async throws {
        // Create a state with iterations below the limit
        let state: GenerationState = createTestState(iterationCount: 9)
            .withStreamComplete(
                output: ProcessedOutput(
                    channels: [
                        ChannelMessage(
                            id: UUID(),
                            type: .final,
                            content: "Complete",
                            order: 0
                        )
                    ]
                ),
                metrics: nil
            )

        let chain: DecisionHandler = buildDecisionChain()
        let decision: GenerationDecision? = try await chain.decide(state)

        // Should pass through to completion handler when below limit
        if case .complete = decision {
            // Expected behavior - completed normally
        } else {
            Issue.record("Expected .complete decision when below max iterations")
        }
    }
}
