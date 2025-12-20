import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for ContextBuilder.build() method with V2 conversation
@Suite("ContextBuilder Build V2 Tests")
internal struct ContextBuilderBuildV2Tests {
    @Test(
        "ContextBuilder produces expected ChatML output for simple conversation V2",
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
    func testChatMLSimpleConversationV2(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let parameters = createChatMLTestParametersV2(architecture: architecture)
        let expectedOutput = try loadExpectedOutputV2()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createChatMLTestParametersV2(architecture: Architecture) -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
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
                userInput: "Great! Now divide that by 5.",
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
            action: .textGeneration([]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedOutputV2() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "output_chatml_simple_conversation_v2",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "output_chatml_simple_conversation_v2.txt"
            )
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
