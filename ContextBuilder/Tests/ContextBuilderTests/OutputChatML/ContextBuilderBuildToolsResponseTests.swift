import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for ContextBuilder.build() method with tools response functionality
@Suite("ContextBuilder Build Tools Response Tests")
internal struct ContextBuilderBuildToolsResponseTests {
    @Test(
        "ContextBuilder produces expected ChatML output with tools response",
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
    func testChatMLToolsResponseOutput(architecture: Architecture) async throws {
        let tooling = MockWeatherTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let parameters = createChatMLToolsResponseTestParameters(architecture: architecture)
        let expectedOutput = try loadExpectedToolsResponseOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createChatMLToolsResponseTestParameters(
        architecture: Architecture
    ) -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )

        let toolCallId = UUID()
        let messages = [
            TestHelpers.createMessageDataWithChannels(
                userInput: "What's the weather in Berlin?",
                channels: [
                    TestHelpers.createCommentaryChannel(
                        content: "I'll check the weather in Berlin for you.",
                        order: 0,
                        associatedToolId: toolCallId
                    )
                ],
                toolCalls: [
                    ToolCall(
                        name: "weather",
                        arguments: "{\"city\": \"Berlin\"}",
                        id: toolCallId.uuidString
                    )
                ]
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        let toolResponse = ToolResponse(
            requestId: UUID(),
            toolName: "weather",
            result: "{\"temperature\": 16, \"condition\": \"Partly cloudy\", \"humidity\": 65}"
        )

        return BuildParameters(
            action: .textGeneration([.weather]),
            contextConfiguration: contextConfig,
            toolResponses: [toolResponse],
            model: model
        )
    }

    private func loadExpectedToolsResponseOutput() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "output_chatml_tools_response",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("output_chatml_tools_response.txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
