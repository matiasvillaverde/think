import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for ContextBuilder.build() method
@Suite("ContextBuilder Build Tests")
internal struct ContextBuilderBuildTests {
    @Test(
        "ContextBuilder produces expected ChatML output for simple conversation",
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
    func testChatMLSimpleConversation(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let parameters = createChatMLTestParameters(architecture: architecture)
        let expectedOutput = try loadExpectedOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createChatMLTestParameters(architecture: Architecture) -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
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

    private func loadExpectedOutput() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "output_chatml_simple_conversation",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("output_chatml_simple_conversation.txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
