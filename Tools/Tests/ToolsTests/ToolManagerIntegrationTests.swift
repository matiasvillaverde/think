@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("ToolManager Integration Tests")
internal struct ToolManagerIntegrationTests {
    @Test("ToolManager executes real tools through ToolExecutor")
    func testToolManagerExecutesRealTools() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()

        // Configure a test tool
        try await toolManager.configureTool(identifiers: [.functions])

        // Create a request
        let request: ToolRequest = ToolRequest(
            name: "functions",
            arguments: "{\"function_name\": \"calculate_sum\", \"parameters\": {\"a\": 5, \"b\": 3}}",
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        #expect(responses.first?.requestId == request.id)
        #expect(responses.first?.toolName == "functions")
        #expect(responses.first?.error == nil)
        #expect(responses.first?.result.contains("Result: 8") == true)
    }

    @Test("ToolManager handles mixed valid and invalid tools")
    func testMixedValidAndInvalidTools() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        try await toolManager.configureTool(identifiers: [.functions])

        let validRequest: ToolRequest = ToolRequest(
            name: "functions",
            arguments: "{\"function_name\": \"get_timestamp\"}",
            id: UUID()
        )

        let invalidRequest: ToolRequest = ToolRequest(
            name: "non_existent_tool",
            arguments: "{}",
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(
            toolRequests: [validRequest, invalidRequest]
        )

        // Then
        #expect(responses.count == 2)

        // Valid request should succeed
        let validResponse: ToolResponse? = responses.first { $0.requestId == validRequest.id }
        #expect(validResponse != nil)
        #expect(validResponse?.error == nil)

        // Invalid request should have error
        let invalidResponse: ToolResponse? = responses.first { $0.requestId == invalidRequest.id }
        #expect(invalidResponse != nil)
        #expect(invalidResponse?.error != nil)
        #expect(invalidResponse?.error?.contains("not found") == true)
    }

    @Test("ToolManager properly delegates to ToolExecutor")
    func testToolManagerDelegation() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()

        // Register a custom tool through future API
        // For now, we test with standard tools
        try await toolManager.configureTool(identifiers: [.python])

        let request: ToolRequest = ToolRequest(
            name: ToolIdentifier.python.rawValue,
            arguments: "{\"code\": \"print('hello')\"}",
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        #expect(responses.first?.toolName == ToolIdentifier.python.rawValue)
    }
}
