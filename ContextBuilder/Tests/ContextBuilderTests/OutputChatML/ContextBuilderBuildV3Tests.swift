import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for ContextBuilder.build() method with extra system prompt information
@Suite("ContextBuilder Build V3 Tests")
internal struct ContextBuilderBuildV3Tests {
    @Test(
        "ContextBuilder produces expected ChatML output with extra system prompt information",
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
    func testChatMLSimpleConversationExtraSystemPrompt(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let parameters = createChatMLTestParametersV3(architecture: architecture)
        let expectedOutput = try loadExpectedOutputV3()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createChatMLTestParametersV3(architecture: Architecture) -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )

        let messages = [
            MessageData(
                id: UUID(),
                createdAt: Date(),
                userInput: "What is 2 + 2?"
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
            action: .textGeneration([]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedOutputV3() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "output_chatml_simple_converstation_extra_system_prompt",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "output_chatml_simple_converstation_extra_system_prompt.txt"
            )
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
