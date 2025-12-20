import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Test: Harmony Input Test Browser And Function Tool")
internal struct HarmonyInputTestBrowserAndFunctionTool {
    @Test(
        "Validates harmony_input_test_browser_and_function_tool",
        arguments: [Architecture.harmony, Architecture.gpt]
    )
    func test(architecture: Architecture) async throws {
        let tooling = MockBrowserAndFunctionsTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let expectedOutput = try loadResource("harmony_input_test_browser_and_function_tool")

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )

        // Basic configuration - adjust based on file name patterns
        let systemInstr = "You are ChatGPT, a large language model trained by OpenAI.\n\nDEVELOPER:"
        let contextConfig = ContextConfiguration(
            systemInstruction: systemInstr,
            contextMessages: [],
            maxPrompt: 4_096,
            reasoningLevel: "medium",
            includeCurrentDate: true,
            knowledgeCutoffDate: "2024-06",
            currentDateOverride: "2025-06-28"
        )

        let parameters = BuildParameters(
            action: .textGeneration([.browser, .functions]),
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
