import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ContextBuilder Qwen History Tests")
internal struct ContextBuilderQwenHistoryTests {
    @Test("ContextBuilder produces expected Qwen output with history and /think command")
    func testQwenConversationWithHistoryAndThink() async throws {
        let tooling = MockReasoningTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let parameters = try createQwenHistoryTestParameters()
        let expectedOutput = try loadExpectedQwenHistoryOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createQwenHistoryTestParameters() throws -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .qwen
        )

        let messages = [
            TestHelpers.createMessageDataWithChannels(
                userInput: "What is 15% of 80?",
                channels: [
                    TestHelpers.createFinalChannel(
                        content: """
                        15% of 80 is 12.

                        To calculate: 80 × 0.15 = 12
                        """,
                        order: 0
                    )
                ]
            ),
            TestHelpers.createMessageDataWithChannels(
                userInput: "Now add 25 to that result",
                channels: []
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "basic",
            includeCurrentDate: true,
            knowledgeCutoffDate: "2024-06",
            currentDateOverride: "2025-08-21"
        )

        return BuildParameters(
            action: .textGeneration([.reasoning]),  // Reasoning enabled, so should add /think
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedQwenHistoryOutput() throws -> String {
        let resource = "output_qwen_simple_converstation_extra_system_prompt_history"
        guard let url = Bundle.module.url(
            forResource: "Example-Qwen/\(resource)",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "Example-Qwen/\(resource).txt"
            )
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
