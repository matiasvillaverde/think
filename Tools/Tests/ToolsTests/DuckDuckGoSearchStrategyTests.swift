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
    func testExecuteSearch() async {
        // Given
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let searchEngine: DuckDuckGoSearch = DuckDuckGoSearch(session: session)
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy(searchEngine: searchEngine)
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
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "duckduckgo_search")
        #expect(response.error == nil)
        #expect(response.result.contains("DuckDuckGo"))
        #expect(response.result.contains("Swift programming"))
    }

    @Test("DuckDuckGoSearchStrategy handles missing query")
    func testMissingQuery() async {
        // Given
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let searchEngine: DuckDuckGoSearch = DuckDuckGoSearch(session: session)
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy(searchEngine: searchEngine)
        let request: ToolRequest = ToolRequest(
            name: "duckduckgo_search",
            arguments: "{}",
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("query") == true)
    }

    @Test("DuckDuckGoSearchStrategy supports instant answers")
    func testInstantAnswers() async {
        // Given
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let searchEngine: DuckDuckGoSearch = DuckDuckGoSearch(session: session)
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy(searchEngine: searchEngine)
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
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("instant answers: enabled"))
    }

    @Test("DuckDuckGoSearchStrategy respects no_redirect option")
    func testNoRedirectOption() async {
        // Given
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let searchEngine: DuckDuckGoSearch = DuckDuckGoSearch(session: session)
        let strategy: DuckDuckGoSearchStrategy = DuckDuckGoSearchStrategy(searchEngine: searchEngine)
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
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("no redirect"))
    }
}
