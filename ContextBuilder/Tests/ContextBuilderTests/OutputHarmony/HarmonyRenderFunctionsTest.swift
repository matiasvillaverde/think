import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Test: Harmony Input Test Render Functions With Parameters")
internal struct HarmonyRenderFunctionsTest {
    @Test(
        "Validates harmony_input_test_render_functions_with_parameters",
        arguments: [Architecture.harmony, Architecture.gpt]
    )
    func test(architecture: Architecture) async throws {
        let tooling = MockFunctionsWithKitchensinkTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let expectedOutput = try loadResource("harmony_input_test_render_functions_with_parameters")

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture,
            locationKind: .huggingFace,
        )

        // Basic configuration - adjust based on file name patterns
        let systemInstruction = """
        You are ChatGPT, a large language model trained by OpenAI.
        DEVELOPER: # Instructions
        """

        let messages = [
            TestHelpers.createMessageDataWithChannels(
                userInput: "What is the weather like in SF?",
                channels: []
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: systemInstruction,
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "high",
            includeCurrentDate: true,
            knowledgeCutoffDate: "2024-06",
            currentDateOverride: "2025-06-28"
        )

        let parameters = BuildParameters(
            action: .textGeneration([.functions]),
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
