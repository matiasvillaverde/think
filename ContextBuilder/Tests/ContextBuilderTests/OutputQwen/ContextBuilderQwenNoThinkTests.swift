import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ContextBuilder Qwen NoThink Tests")
internal struct ContextBuilderQwenNoThinkTests {
    @Test("ContextBuilder produces expected Qwen output with /no_think command")
    func testQwenSimpleConversationWithNoThink() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let parameters = createQwenNoThinkTestParameters()
        let expectedOutput = try loadExpectedQwenNoThinkOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createQwenNoThinkTestParameters() -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .qwen
        )

        let messages = [
            TestHelpers.createMessageDataWithChannels(
                userInput: "What is 2 + 2?",
                channels: [
                    TestHelpers.createFinalChannel(
                        content: "2 + 2 = 4",
                        order: 0
                    )
                ]
            ),
            TestHelpers.createMessageDataWithChannels(
                userInput: "And 3 + 3?",
                channels: []
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant with thinking capabilities.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        return BuildParameters(
            action: .textGeneration([]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedQwenNoThinkOutput() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "Example-Qwen/output_qwen_simple_conversation_nothink",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "Example-Qwen/output_qwen_simple_conversation_nothink.txt"
            )
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
