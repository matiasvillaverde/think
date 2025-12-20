@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("FunctionsStrategy Tests")
internal struct FunctionsStrategyTests {
    @Test("FunctionsStrategy has correct tool definition")
    func testToolDefinition() {
        // Given
        let strategy: FunctionsStrategy = FunctionsStrategy()

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "functions")
        #expect(definition.description.contains("function"))
        #expect(definition.schema.contains("function_name"))
    }

    @Test("FunctionsStrategy calls a function with parameters")
    func testCallFunctionWithParameters() {
        // Given
        let strategy: FunctionsStrategy = FunctionsStrategy()
        let request: ToolRequest = ToolRequest(
            name: "functions",
            arguments: """
            {
                "function_name": "calculate_sum",
                "parameters": {
                    "a": 5,
                    "b": 3
                }
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "functions")
        #expect(response.error == nil)
        #expect(response.result.contains("8") || response.result.contains("sum"))
    }

    @Test("FunctionsStrategy handles missing function_name")
    func testMissingFunctionName() {
        // Given
        let strategy: FunctionsStrategy = FunctionsStrategy()
        let request: ToolRequest = ToolRequest(
            name: "functions",
            arguments: """
            {
                "parameters": {"a": 1}
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("function_name") == true)
    }

    @Test("FunctionsStrategy lists available functions")
    func testListAvailableFunctions() {
        // Given
        let strategy: FunctionsStrategy = FunctionsStrategy()
        let request: ToolRequest = ToolRequest(
            name: "functions",
            arguments: """
            {
                "function_name": "list_functions"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("Available functions"))
    }

    @Test("FunctionsStrategy handles unknown function")
    func testUnknownFunction() {
        // Given
        let strategy: FunctionsStrategy = FunctionsStrategy()
        let request: ToolRequest = ToolRequest(
            name: "functions",
            arguments: """
            {
                "function_name": "unknown_function"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("Unknown function") == true)
    }

    @Test("FunctionsStrategy executes function without parameters")
    func testFunctionWithoutParameters() {
        // Given
        let strategy: FunctionsStrategy = FunctionsStrategy()
        let request: ToolRequest = ToolRequest(
            name: "functions",
            arguments: """
            {
                "function_name": "get_timestamp"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("timestamp") || response.result.contains("2024"))
    }
}
