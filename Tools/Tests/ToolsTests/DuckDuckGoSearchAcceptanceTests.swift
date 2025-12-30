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
        // Given
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let search: DuckDuckGoSearch = DuckDuckGoSearch(session: session)

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
    internal func testDuckDuckGoStrategyIntegration() async {
        // Given
        let toolManager: ToolManager = ToolManager()
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let searchEngine: DuckDuckGoSearch = DuckDuckGoSearch(session: session)
        await toolManager.registerStrategy(DuckDuckGoSearchStrategy(searchEngine: searchEngine))

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
        let responses: [ToolResponse] = await toolManager.executeTools(toolRequests: [request])

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
    internal func testBrowserSearchStrategyIntegration() async {
        // Given
        let toolManager: ToolManager = ToolManager()
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let searchEngine: DuckDuckGoSearch = DuckDuckGoSearch(session: session)
        await toolManager.registerStrategy(BrowserSearchStrategy(searchEngine: searchEngine))

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
        let responses: [ToolResponse] = await toolManager.executeTools(toolRequests: [request])

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

    @Test("DuckDuckGo search with site filter")
    internal func testDuckDuckGoSearchWithSiteFilter() async throws {
        // Given
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let search: DuckDuckGoSearch = DuckDuckGoSearch(session: session)

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

    @Test("DuckDuckGo search handles various content types")
    internal func testDuckDuckGoContentExtraction() async throws {
        // Given
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let search: DuckDuckGoSearch = DuckDuckGoSearch(session: session)

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
        #expect(result.content.count > 200) // Should extract substantial content
        #expect(result.content.count > result.snippet.count * 3) // Much more than snippet

        // Verify content is cleaned and formatted
        #expect(!result.content.contains("<script>")) // Should remove script tags
        #expect(!result.content.contains("<style>")) // Should remove style tags
    }

    @Test("Browser search with site parameter")
    internal func testBrowserSearchWithSiteParameter() async {
        // Given
        let toolManager: ToolManager = ToolManager()
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let searchEngine: DuckDuckGoSearch = DuckDuckGoSearch(session: session)
        await toolManager.registerStrategy(BrowserSearchStrategy(searchEngine: searchEngine))

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
        let responses: [ToolResponse] = await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        let response: ToolResponse = responses[0]
        #expect(response.error == nil)
        #expect(!response.result.isEmpty)
        #expect(response.result.contains("site: github.com"))
        #expect(response.result.contains("github.com"))
    }

    @Test("DuckDuckGo configuration and customization")
    internal func testDuckDuckGoConfiguration() async throws {
        // Given - Custom configuration
        let customConfig: DuckDuckGoSearch.Configuration = DuckDuckGoSearch.Configuration(
            maxResultCount: 3,
            requestTimeout: 20.0,
            concurrentFetches: 2
        )
        let session: URLSession = DuckDuckGoStub.makeSession(handler: DuckDuckGoStub.defaultHandler(for:))
        defer { DuckDuckGoStub.reset() }
        let search: DuckDuckGoSearch = DuckDuckGoSearch(configuration: customConfig, session: session)

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
    internal func testDuckDuckGoSearchErrorHandling() async {
        // Given
        let toolManager: ToolManager = ToolManager()
        await toolManager.configureTool(identifiers: [.duckduckgo])

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

        let responses: [ToolResponse] = await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        let response: ToolResponse = responses[0]
        #expect(response.error != nil)
        #expect(response.error?.contains("Missing required parameter: query") == true)
    }
}
