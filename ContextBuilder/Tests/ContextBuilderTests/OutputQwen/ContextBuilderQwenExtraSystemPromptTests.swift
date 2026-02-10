import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ContextBuilder Qwen Extra System Prompt Tests")
internal struct ContextBuilderQwenExtraSystemPromptTests {
    @Test("Qwen output with extra system prompt (no /think directives)")
    func testQwenSimpleConversationExtraSystemPrompt() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let parameters = createQwenExtraSystemPromptTestParameters()
        let expectedOutput = try loadExpectedQwenExtraSystemPromptOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createQwenExtraSystemPromptTestParameters() -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .qwen,
            locationKind: .huggingFace,
        )

        let messages = [
            TestHelpers.createMessageDataWithChannels(
                userInput: "What is 2 + 2?",
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

    private func loadExpectedQwenExtraSystemPromptOutput() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "Example-Qwen/output_qwen_simple_converstation_extra_system_prompt",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "Example-Qwen/output_qwen_simple_converstation_extra_system_prompt.txt"
            )
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
