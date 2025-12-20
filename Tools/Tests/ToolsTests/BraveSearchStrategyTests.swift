@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("BraveSearchStrategy Tests")
internal struct BraveSearchStrategyTests {
    @Test("BraveSearchStrategy has correct tool definition")
    func testToolDefinition() {
        // Given
        let strategy: BraveSearchStrategy = BraveSearchStrategy()

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "brave_search")
        #expect(definition.description.contains("Brave"))
        #expect(definition.schema.contains("query"))
    }

    @Test("BraveSearchStrategy executes search with query")
    func testExecuteSearch() {
        // Given
        let strategy: BraveSearchStrategy = BraveSearchStrategy()
        let request: ToolRequest = ToolRequest(
            name: "brave_search",
            arguments: """
            {
                "query": "Swift programming",
                "freshness": "week"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "brave_search")
        #expect(response.error == nil)
        #expect(response.result.contains("Brave search"))
        #expect(response.result.contains("Swift programming"))
    }

    @Test("BraveSearchStrategy handles missing query")
    func testMissingQuery() {
        // Given
        let strategy: BraveSearchStrategy = BraveSearchStrategy()
        let request: ToolRequest = ToolRequest(
            name: "brave_search",
            arguments: "{}",
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("query") == true)
    }

    @Test("BraveSearchStrategy supports safe search")
    func testSafeSearch() {
        // Given
        let strategy: BraveSearchStrategy = BraveSearchStrategy()
        let request: ToolRequest = ToolRequest(
            name: "brave_search",
            arguments: """
            {
                "query": "test",
                "safe_search": "strict"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("safe search: strict"))
    }
}
