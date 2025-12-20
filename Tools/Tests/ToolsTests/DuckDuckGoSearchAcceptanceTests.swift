@testable import Abstractions
@testable import AbstractionsTestUtilities
import Foundation
import Testing
@testable import Tools

// MARK: - Serialized Acceptance Tests
// These tests make real network requests to DuckDuckGo and must run serially
// to avoid rate limiting and IP blocking
@Suite("DuckDuckGo Search Acceptance Tests", .serialized, .tags(.acceptance))
internal struct DuckDuckGoSearchAcceptanceTests {
    @Test("DuckDuckGo search actor performs basic search")
    internal func testDuckDuckGoSearchBasicFunctionality() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given
        let search: DuckDuckGoSearch = DuckDuckGoSearch()

        // When - Search for a reliable query
        let results: [WebSearchResult] = try await search.search(
            query: "Swift programming language",
            resultCount: 2
        )

        // Then
        #expect(results.count >= 1)
        #expect(results.count <= 2)

        let firstResult: WebSearchResult = results[0]
        #expect(!firstResult.title.isEmpty)
        #expect(!firstResult.sourceURL.isEmpty)
        #expect(!firstResult.snippet.isEmpty)
        #expect(!firstResult.content.isEmpty) // This is the key difference - full content!
        #expect(firstResult.content.count > firstResult.snippet.count) // Content should be longer than snippet
    }

    @Test("DuckDuckGo search strategy through ToolManager")
    internal func testDuckDuckGoStrategyIntegration() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given
        let toolManager: ToolManager = ToolManager()

        try await toolManager.configureTool(identifiers: [.duckduckgo])

        let request: ToolRequest = ToolRequest(
            name: "duckduckgo_search",
            arguments: """
            {
                "query": "Swift programming",
                "count": 2
            }
            """,
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        let response: ToolResponse = responses[0]
        #expect(response.requestId == request.id)
        #expect(response.toolName == "duckduckgo_search")
        #expect(response.error == nil)
        #expect(!response.result.isEmpty)

        // Verify the response contains structured search results
        #expect(response.result.contains("DuckDuckGo search results"))
        #expect(response.result.contains("Found"))
        #expect(response.result.contains("URL:"))
        #expect(response.result.contains("Content:")) // Verify full content is included
    }

    @Test("Browser search strategy through ToolManager")
    internal func testBrowserSearchStrategyIntegration() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given
        let toolManager: ToolManager = ToolManager()

        try await toolManager.configureTool(identifiers: [.browser])

        let request: ToolRequest = ToolRequest(
            name: "browser.search",
            arguments: """
            {
                "query": "Apple Swift",
                "resultCount": 2
            }
            """,
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        let response: ToolResponse = responses[0]
        #expect(response.requestId == request.id)
        #expect(response.toolName == "browser.search")
        #expect(response.error == nil)
        #expect(!response.result.isEmpty)

        // Verify the response contains structured search results with content
        #expect(response.result.contains("Web search results"))
        #expect(response.result.contains("Found"))
        #expect(response.result.contains("URL:"))
        #expect(response.result.contains("Content:")) // Verify full content extraction
    }

    @Test("DuckDuckGo search with site filter", .disabled("DuckDuckGo bot detection causing failures"))
    internal func testDuckDuckGoSearchWithSiteFilter() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given
        let search: DuckDuckGoSearch = DuckDuckGoSearch()

        // When - Search with site filter
        let results: [WebSearchResult] = try await search.search(
            query: "Swift",
            site: "apple.com",
            resultCount: 3
        )

        // Then
        #expect(results.count >= 1)
        #expect(results.count <= 3)

        // Verify that at least one result is from apple.com domain
        let hasAppleResult: Bool = results.contains { result in
            result.sourceURL.contains("apple.com")
        }
        #expect(hasAppleResult)
    }

    @Test("DuckDuckGo search handles various content types", .disabled("DuckDuckGo bot detection causing failures"))
    internal func testDuckDuckGoContentExtraction() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given
        let search: DuckDuckGoSearch = DuckDuckGoSearch()

        // When - Search for technical content
        let results: [WebSearchResult] = try await search.search(
            query: "Swift documentation",
            resultCount: 1
        )

        // Then
        #expect(results.count >= 1)

        let result: WebSearchResult = results[0]

        // Verify sophisticated content extraction
        #expect(!result.title.isEmpty)
        #expect(!result.snippet.isEmpty)
        #expect(!result.content.isEmpty)
        #expect(!result.sourceURL.isEmpty)

        // Content should be substantially longer than snippet due to full page extraction
        #expect(result.content.count > 500) // Should extract substantial content
        #expect(result.content.count > result.snippet.count * 3) // Much more than snippet

        // Verify content is cleaned and formatted
        #expect(!result.content.contains("<script>")) // Should remove script tags
        #expect(!result.content.contains("<style>")) // Should remove style tags
    }

    @Test("Browser search with site parameter", .disabled("DuckDuckGo bot detection causing failures"))
    internal func testBrowserSearchWithSiteParameter() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given
        let toolManager: ToolManager = ToolManager()
        try await toolManager.configureTool(identifiers: [.browser])

        let request: ToolRequest = ToolRequest(
            name: "browser.search",
            arguments: """
            {
                "query": "Swift",
                "site": "github.com",
                "resultCount": 2
            }
            """,
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        let response: ToolResponse = responses[0]
        #expect(response.error == nil)
        #expect(!response.result.isEmpty)
        #expect(response.result.contains("site: github.com"))
        #expect(response.result.contains("github.com"))
    }

    @Test("DuckDuckGo configuration and customization", .disabled("DuckDuckGo bot detection causing failures"))
    internal func testDuckDuckGoConfiguration() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given - Custom configuration
        let customConfig: DuckDuckGoSearch.Configuration = DuckDuckGoSearch.Configuration(
            maxResultCount: 3,
            requestTimeout: 20.0,
            concurrentFetches: 2
        )
        let search: DuckDuckGoSearch = DuckDuckGoSearch(configuration: customConfig)

        // When
        let results: [WebSearchResult] = try await search.search(
            query: "Swift programming",
            resultCount: 3
        )

        // Then - Should respect configuration
        #expect(results.count >= 1)
        #expect(results.count <= 3)

        // All results should have content due to sophisticated implementation
        for result in results {
            #expect(!result.content.isEmpty)
            #expect(result.content.count > 100) // Substantial content
        }
    }
}

// MARK: - Non-Network Tests
// These tests don't make real network requests and can run in parallel
@Suite("DuckDuckGo Search Unit Tests")
internal struct DuckDuckGoSearchUnitTests {
    @Test("DuckDuckGo search error handling")
    internal func testDuckDuckGoSearchErrorHandling() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        try await toolManager.configureTool(identifiers: [.duckduckgo])

        // When - Invalid request with missing query
        let request: ToolRequest = ToolRequest(
            name: "duckduckgo_search",
            arguments: """
            {
                "count": 5
            }
            """,
            id: UUID()
        )

        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        let response: ToolResponse = responses[0]
        #expect(response.error != nil)
        #expect(response.error?.contains("Missing required parameter: query") == true)
    }
}
