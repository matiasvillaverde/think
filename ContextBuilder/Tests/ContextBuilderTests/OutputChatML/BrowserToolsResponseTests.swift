import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for ContextBuilder.build() method with browser tools response functionality
@Suite("ContextBuilder Build Browser Tools Response Tests")
internal struct BrowserToolsResponseTests {
    @Test(
        "ContextBuilder produces expected ChatML output with browser tools response",
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
    func testChatMLBrowserToolsResponseOutput(architecture: Architecture) async throws {
        let tooling = MockBrowserTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let parameters = createChatMLBrowserToolsResponseTestParameters(
            architecture: architecture
        )
        let expectedOutput = try loadExpectedBrowserToolsResponseOutput()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createChatMLBrowserToolsResponseTestParameters(
        architecture: Architecture
    ) -> BuildParameters {
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture,
            locationKind: .huggingFace,
        )

        let toolCallId = UUID()
        let messages = [
            TestHelpers.createMessageDataWithChannels(
                userInput: "Search for the latest news about AI development",
                channels: [
                    TestHelpers.createCommentaryChannel(
                        content: "I'll search for the latest news about AI development.",
                        order: 0,
                        associatedToolId: toolCallId
                    )
                ],
                toolCalls: [
                    ToolCall(
                        name: "browser.search",
                        arguments: "{\"query\": \"latest AI development news\", " +
                            "\"max_results\": 5}",
                        id: toolCallId.uuidString
                    )
                ]
            )
        ]

        let contextConfig = ContextConfiguration(
            systemInstruction: "You are a helpful assistant.",
            contextMessages: messages,
            maxPrompt: 4_096,
            includeCurrentDate: false
        )

        let toolResponse = ToolResponse(
            requestId: UUID(),
            toolName: "browser.search",
            result: "{\"results\": [{\"title\": \"OpenAI Releases GPT-5\", " +
                "\"url\": \"https://example.com\", " +
                "\"snippet\": \"Major breakthrough in AI\"}], " +
                "\"search_query\": \"latest AI development news\", \"total_results\": 1}"
        )

        return BuildParameters(
            action: .textGeneration([.browser]),
            contextConfiguration: contextConfig,
            toolResponses: [toolResponse],
            model: model
        )
    }

    private func loadExpectedBrowserToolsResponseOutput() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "output_chatml_browser_tools_response",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "output_chatml_browser_tools_response.txt"
            )
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}
