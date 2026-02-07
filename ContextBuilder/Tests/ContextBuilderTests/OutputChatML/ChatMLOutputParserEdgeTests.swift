import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ChatML Output Parser Edge Tests")
internal struct ChatMLOutputParserEdgeTests {
    @Test("Parses multiple tool calls")
    func testMultipleToolCalls() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama,
            locationKind: .huggingFace,
        )

        let output = [
            "<commentary>Do it</commentary>",
            "<tool_call>{\"name\":\"search\",\"arguments\":{\"q\":\"x\"}}</tool_call>",
            "<tool_call>{\"name\":\"weather\",\"arguments\":{\"city\":\"SF\"}}</tool_call>",
            "Final"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 4)
        #expect(result.channels[0].type == .commentary)
        #expect(result.channels[1].type == .tool)
        #expect(result.channels[1].toolRequest?.name == "search")
        #expect(result.channels[2].type == .tool)
        #expect(result.channels[2].toolRequest?.name == "weather")
        #expect(result.channels[3].type == .final)
        #expect(result.channels[3].content == "Final")
    }

    @Test("Parses tool_calls array payloads")
    func testToolCallsArrayPayload() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama,
            locationKind: .huggingFace,
        )

        let toolCall = [
            "<tool_call>{\"tool_calls\":[{\"id\":\"call_1\",",
            "\"type\":\"function\",\"function\":{\"name\":\"browser.search\",",
            "\"arguments\":\"{\\\"query\\\":\\\"Swift\\\"}\"}}]}</tool_call>"
        ].joined()

        let output = [
            toolCall,
            "Final"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 2)
        #expect(result.channels[0].type == .tool)
        #expect(result.channels[0].toolRequest?.name == "browser.search")
        #expect(result.channels[0].toolRequest?.arguments.contains(#""query":"Swift""#) == true)
        #expect(result.channels[1].type == .final)
        #expect(result.channels[1].content == "Final")
    }

    @Test("Normalizes workspace tool name with action suffix")
    func testWorkspaceToolNameNormalization() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama,
            locationKind: .huggingFace,
        )

        let toolCall = [
            "<tool_call>{\"name\":\"workspace.write\",\"arguments\":{\"action\":\"write\",",
            "\"path\":\"notes.md\",\"content\":\"Hello\"}}</tool_call>"
        ].joined()

        let output = [
            toolCall,
            "Final"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 2)
        #expect(result.channels[0].type == .tool)
        #expect(result.channels[0].toolRequest?.name == "workspace")
        #expect(result.channels[0].toolRequest?.arguments.contains("notes.md") == true)
        #expect(result.channels[1].type == .final)
        #expect(result.channels[1].content == "Final")
    }

    @Test("Empty commentary tags do not create channel")
    func testEmptyCommentaryIgnored() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama,
            locationKind: .huggingFace,
        )

        let output = "<commentary>\n</commentary>Final"
        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 1)
        #expect(result.channels[0].type == .final)
        #expect(result.channels[0].content == "Final")
    }
}
