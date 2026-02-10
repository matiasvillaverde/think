import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ContextBuilder Qwen Tools Tests")
internal struct ContextBuilderQwenToolsTests {
    @Test("Qwen output with tools (no /think directives)")
    func testQwenTools() async throws {
        let tooling = MockWeatherTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let parameters = createQwenToolsTestParameters()
        let expectedOutput = try loadExpectedQwenToolsOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createQwenToolsTestParameters() -> BuildParameters {
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
                userInput: "Weather in Paris?",
                channels: []
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            includeCurrentDate: false
        )

        return BuildParameters(
            action: .textGeneration([.weather]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedQwenToolsOutput() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "Example-Qwen/output_qwen_tools",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "Example-Qwen/output_qwen_tools.txt"
            )
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
