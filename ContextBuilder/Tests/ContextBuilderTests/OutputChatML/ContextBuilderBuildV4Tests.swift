import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for ContextBuilder.build() method with conversation history and extra system prompt info
@Suite("ContextBuilder Build V4 Tests")
internal struct ContextBuilderBuildV4Tests {
    @Test(
        """
        ContextBuilder produces expected ChatML output with conversation history and \
        extra system prompt information
        """,
        arguments: [
            Architecture.yi,
            Architecture.phi,
            Architecture.phi4,
            Architecture.baichuan,
            Architecture.chatglm,
            Architecture.smol,
            Architecture.falcon,
            Architecture.gemma
        ]
    )
    func testChatMLSimpleConversationExtraSystemPromptHistory(
        architecture: Architecture
    ) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let parameters = createChatMLTestParametersV4(architecture: architecture)
        let expectedOutput = try loadExpectedOutputV4()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createChatMLTestParametersV4(architecture: Architecture) -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture,
            locationKind: .huggingFace,
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
            includeCurrentDate: true,
            knowledgeCutoffDate: "2024-06",
            currentDateOverride: "2025-08-21"
        )

        return BuildParameters(
            action: .textGeneration([]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedOutputV4() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "output_chatml_simple_converstation_extra_system_prompt_history",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "output_chatml_simple_converstation_extra_system_prompt_history.txt"
            )
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
