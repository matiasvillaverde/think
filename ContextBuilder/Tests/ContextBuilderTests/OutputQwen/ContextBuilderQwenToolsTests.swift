import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ContextBuilder Qwen Tools Tests")
internal struct ContextBuilderQwenToolsTests {
    @Test("Qwen output with tools and /think command when reasoning is enabled")
    func testQwenToolsWithThinkCommand() async throws {
        let tooling = MockWeatherAndReasoningTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let parameters = createQwenToolsTestParametersWithReasoning()
        let expectedOutput = try loadExpectedQwenToolsOutputWithThink()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    @Test("Qwen output with tools and /no_think command when reasoning is disabled")
    func testQwenToolsWithNoThinkCommand() async throws {
        let tooling = MockWeatherTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let parameters = createQwenToolsTestParametersWithoutReasoning()
        let expectedOutput = try loadExpectedQwenToolsOutputWithNoThink()

        let result = try await contextBuilder.build(parameters: parameters)

        let areEquivalent = TestHelpers.areEquivalent(result, expectedOutput)
        let detailedDiff = TestHelpers.createDetailedDiff(
            actual: result,
            expected: expectedOutput
        )
        #expect(areEquivalent, Comment(rawValue: detailedDiff))
    }

    private func createQwenToolsTestParametersWithReasoning() -> BuildParameters {
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
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        // Include both weather and reasoning tools
        let reasoningAction: Action = .textGeneration([.weather, .reasoning])
        return BuildParameters(
            action: reasoningAction,
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func createQwenToolsTestParametersWithoutReasoning() -> BuildParameters {
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
            reasoningLevel: "basic",
            includeCurrentDate: false
        )

        let noReasoningAction: Action = .textGeneration([.weather])
        return BuildParameters(
            action: noReasoningAction,
            contextConfiguration: contextConfig,
            toolResponses: [],
            model: model
        )
    }

    private func loadExpectedQwenToolsOutputWithThink() throws -> String {
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

    private func loadExpectedQwenToolsOutputWithNoThink() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "Example-Qwen/output_qwen_tools_nothink",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound(
                "Example-Qwen/output_qwen_tools_nothink.txt"
            )
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
