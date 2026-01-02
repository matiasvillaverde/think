import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Test: Harmony Input Test Simple Convo High Effort No Instruction")
internal struct HarmonySimpleConvoHighNoInstr {
    @Test(
        "Validates harmony_input_test_simple_convo_high_effort_no_instruction",
        arguments: [Architecture.harmony, Architecture.gpt]
    )
    func test(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let expectedOutput = try loadResource(
            "harmony_input_test_simple_convo_high_effort_no_instruction"
        )

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture,
            locationKind: .huggingFace,
        )

        // Basic configuration - adjust based on file name patterns
        let messages = [
            TestHelpers.createMessageDataWithChannels(
                userInput: "What is the capital of the largest country in the world?",
                channels: []
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are ChatGPT, a large language model trained by OpenAI.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "high",
            includeCurrentDate: false,
            knowledgeCutoffDate: "2024-06"
        )

        let parameters = BuildParameters(
            action: .textGeneration([]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let diff = TestHelpers.createDetailedDiff(actual: result, expected: expectedOutput)
        #expect(areEquivalent, Comment(rawValue: diff))
    }

    private func loadResource(_ name: String) throws -> String {
        guard let url = Bundle.module.url(
            forResource: "Examples-Harmony/\(name)",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("Examples-Harmony/\(name).txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
