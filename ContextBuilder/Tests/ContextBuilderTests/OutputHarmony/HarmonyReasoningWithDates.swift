import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Test: Harmony Input Test Reasoning System Message With Dates")
internal struct HarmonyReasoningWithDates {
    @Test(
        "Validates harmony_input_test_reasoning_system_message_with_dates",
        arguments: [Architecture.harmony, Architecture.gpt]
    )
    func test(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let expectedOutput = try loadResource(
            "harmony_input_test_reasoning_system_message_with_dates"
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
                userInput: "What is 42 * pi?",
                channels: []
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are ChatGPT, a large language model trained by OpenAI.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "medium",
            includeCurrentDate: true,
            knowledgeCutoffDate: "2021-01",
            currentDateOverride: "2021-01-01"
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
