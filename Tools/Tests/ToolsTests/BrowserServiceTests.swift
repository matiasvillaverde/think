@testable import Abstractions
import Foundation
import Testing
@testable import Tools

// MARK: - Unit Tests
// These tests don't make real network requests and can run in parallel
@Suite("BrowserService Tests")
internal struct BrowserServiceTests {
    @Test("BrowserService registers search tool")
    func testBrowserServiceRegistersSearchTool() async throws {
        // Given
        let service: BrowserService = BrowserService()
        let toolManager: ToolManager = ToolManager()

        // When
        await service.registerTools(with: toolManager)
        let tools: [ToolDefinition] = await toolManager.getAllToolDefinitions()

        // Then
        #expect(tools.contains { $0.name == "browser.search" })
        let searchTool: ToolDefinition? = tools.first { $0.name == "browser.search" }
        #expect(searchTool != nil)
        #expect(searchTool?.description.contains("Search the web") == true)
    }

    @Test("BrowserService handles invalid arguments")
    func testBrowserServiceHandlesInvalidArguments() async throws {
        // Given
        let service: BrowserService = BrowserService()
        let toolManager: ToolManager = ToolManager()
        await service.registerTools(with: toolManager)

        let request: ToolRequest = ToolRequest(
            name: "browser.search",
            arguments: "{}",  // Missing required query parameter
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        #expect(responses.first?.error != nil)
        #expect(responses.first?.error?.contains("query") == true)
    }
}

// MARK: - Serialized Acceptance Tests
// These tests make real network requests and must run serially to avoid rate limiting
@Suite("BrowserService Acceptance Tests", .serialized, .tags(.acceptance))
internal struct BrowserServiceAcceptanceTests {
    @Test("BrowserService executes search with query")
    func testBrowserServiceExecutesSearch() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given
        let service: BrowserService = BrowserService()
        let toolManager: ToolManager = ToolManager()
        await service.registerTools(with: toolManager)

        let request: ToolRequest = ToolRequest(
            name: "browser.search",
            arguments: "{\"query\": \"Swift programming\"}",
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        #expect(responses.first?.requestId == request.id)
        #expect(responses.first?.toolName == "browser.search")
        #expect(responses.first?.error == nil)
        #expect(responses.first?.result.isEmpty == false)
    }

    @Test("BrowserService search with site filter", .disabled("DuckDuckGo bot detection causing failures"))
    func testBrowserServiceSearchWithSiteFilter() async throws {
        // Add delay to prevent rate limiting when running tests in sequence
        try await Task.sleep(for: .seconds(1))

        // Given
        let service: BrowserService = BrowserService()
        let toolManager: ToolManager = ToolManager()
        await service.registerTools(with: toolManager)

        let request: ToolRequest = ToolRequest(
            name: "browser.search",
            arguments: "{\"query\": \"SwiftUI\", \"site\": \"developer.apple.com\"}",
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        #expect(responses.first?.error == nil)
        // In a real implementation, we'd verify the site filter was applied
    }
}
