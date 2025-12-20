@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("DuckDuckGoSearchStrategy Tests")
internal struct DuckDuckGoSearchStrategyTests {
    @Test("DuckDuckGoSearchStrategy has correct tool definition")
    func testToolDefinition() {
        // Given
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy()

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "duckduckgo_search")
        #expect(definition.description.contains("DuckDuckGo"))
        #expect(definition.schema.contains("query"))
    }

    @Test("DuckDuckGoSearchStrategy executes search with query")
    func testExecuteSearch() {
        // Given
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy()
        let request: ToolRequest = ToolRequest(
            name: "duckduckgo_search",
            arguments: """
            {
                "query": "Swift programming",
                "region": "us-en"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "duckduckgo_search")
        #expect(response.error == nil)
        #expect(response.result.contains("DuckDuckGo"))
        #expect(response.result.contains("Swift programming"))
    }

    @Test("DuckDuckGoSearchStrategy handles missing query")
    func testMissingQuery() {
        // Given
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy()
        let request: ToolRequest = ToolRequest(
            name: "duckduckgo_search",
            arguments: "{}",
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("query") == true)
    }

    @Test("DuckDuckGoSearchStrategy supports instant answers")
    func testInstantAnswers() {
        // Given
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy()
        let request: ToolRequest = ToolRequest(
            name: "duckduckgo_search",
            arguments: """
            {
                "query": "weather",
                "instant_answers": true
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("instant answers: enabled"))
    }

    @Test("DuckDuckGoSearchStrategy respects no_redirect option")
    func testNoRedirectOption() {
        // Given
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy()
        let request: ToolRequest = ToolRequest(
            name: "duckduckgo_search",
            arguments: """
            {
                "query": "test",
                "no_redirect": true
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("no redirect"))
    }
}
