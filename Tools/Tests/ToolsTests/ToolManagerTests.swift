@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("ToolManager Tests")
internal struct ToolManagerTests {
    @Test("Initialize ToolManager")
    func testInitialization() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()

        // When
        let definitions: [ToolDefinition] = await toolManager.getAllToolDefinitions()

        // Then
        #expect(definitions.isEmpty)
    }

    @Test("Configure single tool")
    func testConfigureSingleTool() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        let identifiers: Set<ToolIdentifier> = [.browser]

        // When
        try await toolManager.configureTool(identifiers: identifiers)
        let definitions: [ToolDefinition] = await toolManager.getAllToolDefinitions()

        // Then
        #expect(definitions.count == 1)
        // The browser identifier registers browser.search tool
        #expect(definitions.first?.name == "browser.search")
    }

    @Test("Configure multiple tools")
    func testConfigureMultipleTools() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        let identifiers: Set<ToolIdentifier> = [.browser, .python, .functions]

        // When
        try await toolManager.configureTool(identifiers: identifiers)
        let definitions: [ToolDefinition] = await toolManager.getAllToolDefinitions()

        // Then
        // All configured tools should be registered
        #expect(definitions.count == 3)
        let names: Set<String> = Set(definitions.map(\.name))
        #expect(names.contains("browser.search"))
        #expect(names.contains("python_exec"))
        #expect(names.contains("functions"))
    }

    @Test("Clear configured tools")
    func testClearTools() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        try await toolManager.configureTool(identifiers: [.browser, .python])

        // When
        await toolManager.clearTools()
        let definitions: [ToolDefinition] = await toolManager.getAllToolDefinitions()

        // Then
        #expect(definitions.isEmpty)
    }

    @Test("Get tool definitions for specific identifiers")
    func testGetToolDefinitionsForIdentifiers() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        let allIdentifiers: Set<ToolIdentifier> = [.browser, .python, .functions]
        try await toolManager.configureTool(identifiers: allIdentifiers)

        // When
        let requestedIdentifiers: Set<ToolIdentifier> = [.browser, .functions]
        let definitions: [ToolDefinition] = await toolManager.getToolDefinitions(for: requestedIdentifiers)

        // Then
        // Both browser and functions are implemented and requested
        #expect(definitions.count == 2)
        let names: Set<String> = Set(definitions.map(\.name))
        #expect(names.contains("browser.search"))
        #expect(names.contains("functions"))
    }

    @Test("Execute tool request for configured tool")
    func testExecuteConfiguredTool() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        try await toolManager.configureTool(identifiers: [.functions])

        let request: ToolRequest = ToolRequest(
            name: "functions",
            arguments: "{\"function_name\": \"get_timestamp\"}",
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        #expect(responses.first?.requestId == request.id)
        #expect(responses.first?.toolName == "functions")
        #expect(responses.first?.error == nil)
        #expect(responses.first?.result.contains("timestamp") ?? false)
    }

    @Test("Execute tool request for unconfigured tool returns error")
    func testExecuteUnconfiguredTool() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        // Not configuring any tools

        let request: ToolRequest = ToolRequest(
            name: "UnknownTool",
            arguments: "{}",
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(toolRequests: [request])

        // Then
        #expect(responses.count == 1)
        #expect(responses.first?.error != nil)
        #expect(responses.first?.error?.contains("not found") == true)
    }

    @Test("Execute multiple tool requests")
    func testExecuteMultipleToolRequests() async throws {
        // Given
        let toolManager: ToolManager = ToolManager()
        try await toolManager.configureTool(identifiers: [.browser, .python])

        let request1: ToolRequest = ToolRequest(
            name: ToolIdentifier.browser.rawValue,
            arguments: "{}",
            id: UUID()
        )
        let request2: ToolRequest = ToolRequest(
            name: ToolIdentifier.python.rawValue,
            arguments: "{}",
            id: UUID()
        )

        // When
        let responses: [ToolResponse] = try await toolManager.executeTools(
            toolRequests: [request1, request2]
        )

        // Then
        #expect(responses.count == 2)
        #expect(responses.contains { $0.requestId == request1.id })
        #expect(responses.contains { $0.requestId == request2.id })
    }
}
