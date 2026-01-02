import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ContextBuilder ChatML Think Tests")
internal struct ContextBuilderChatMLThinkTests {
    @Test("ContextBuilder produces expected ChatML output with /think command for Qwen")
    func testChatMLSimpleConversationWithThink() async throws {
        let tooling = MockReasoningTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let parameters = createChatMLThinkTestParameters()
        let expectedOutput = try loadExpectedChatMLThinkOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createChatMLThinkTestParameters() -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .qwen,
            locationKind: .huggingFace,
        )

        let messages = [
            TestHelpers.createMessageDataWithChannels(
                userInput: "What is 25 * 37?",
                channels: [
                    TestHelpers.createFinalChannel(
                        content: """
                        25 * 37 = 925

                        To calculate this:
                        - 25 * 30 = 750
                        - 25 * 7 = 175
                        - 750 + 175 = 925
                        """,
                        order: 0
                    )
                ]
            ),
            TestHelpers.createMessageDataWithChannels(
                userInput: "Great! Now divide that by 5",
                channels: []
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful AI assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        return BuildParameters(
            action: .textGeneration([.reasoning]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedChatMLThinkOutput() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "Example-Qwen/output_qwen_simple_conversation_think",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "Example-Qwen/output_qwen_simple_conversation_think.txt"
            )
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
