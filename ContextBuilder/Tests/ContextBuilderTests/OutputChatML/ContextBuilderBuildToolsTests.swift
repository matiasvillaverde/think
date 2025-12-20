import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for ContextBuilder.build() method with tools functionality
@Suite("ContextBuilder Build Tools Tests")
internal struct ContextBuilderBuildToolsTests {
    @Test(
        "ContextBuilder produces expected ChatML output with tools",
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
    func testChatMLToolsOutput(architecture: Architecture) async throws {
        let tooling = MockWeatherTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let parameters = createChatMLToolsTestParameters(architecture: architecture)
        let expectedOutput = try loadExpectedToolsOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createChatMLToolsTestParameters(architecture: Architecture) -> BuildParameters {
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
                userInput: "Weather in Paris?",
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        return BuildParameters(
            action: .textGeneration([.weather]),
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedToolsOutput() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "output_chatml_tools",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("output_chatml_tools.txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
