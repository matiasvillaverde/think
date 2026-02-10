import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Test: No Tools")
internal struct HarmonyTestNoTools {
    @Test(
        "Validates harmony_input_test_no_tools",
        arguments: [Architecture.harmony, Architecture.gpt]
    )
    func testNoTools(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let expectedOutput = try loadResource("harmony_input_test_no_tools")

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture,
            locationKind: .huggingFace,
        )

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are ChatGPT, a large language model trained by OpenAI.",
            contextMessages: [],
            maxPrompt: 4_096,
            includeCurrentDate: true,
            knowledgeCutoffDate: "2024-06",
            currentDateOverride: "2025-06-28"
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
