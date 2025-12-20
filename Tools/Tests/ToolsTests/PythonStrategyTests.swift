@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("PythonStrategy Tests")
internal struct PythonStrategyTests {
    @Test("PythonStrategy has correct tool definition")
    func testToolDefinition() {
        // Given
        let strategy: PythonStrategy = PythonStrategy()

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "python_exec")
        #expect(definition.description.contains("Python"))
        #expect(definition.schema.contains("code"))
    }

    @Test("PythonStrategy executes simple Python code")
    func testExecuteSimplePythonCode() {
        // Given
        let strategy: PythonStrategy = PythonStrategy()
        let request: ToolRequest = ToolRequest(
            name: "python_exec",
            arguments: """
            {
                "code": "print('Hello, World!')"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "python_exec")
        #expect(response.error == nil)
        #expect(response.result.contains("Hello, World!"))
    }

    @Test("PythonStrategy handles missing code parameter")
    func testMissingCodeParameter() {
        // Given
        let strategy: PythonStrategy = PythonStrategy()
        let request: ToolRequest = ToolRequest(
            name: "python_exec",
            arguments: "{}",
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("code") == true)
    }

    @Test("PythonStrategy executes math operations")
    func testExecuteMathOperations() {
        // Given
        let strategy: PythonStrategy = PythonStrategy()
        let request: ToolRequest = ToolRequest(
            name: "python_exec",
            arguments: """
            {
                "code": "result = 5 + 3\\nprint(f'Result: {result}')"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("Result: 8"))
    }

    @Test("PythonStrategy handles syntax errors")
    func testHandleSyntaxErrors() {
        // Given
        let strategy: PythonStrategy = PythonStrategy()
        let request: ToolRequest = ToolRequest(
            name: "python_exec",
            arguments: """
            {
                "code": "print('missing closing quote)"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("SyntaxError") == true)
    }

    @Test("PythonStrategy respects timeout")
    func testRespectTimeout() {
        // Given
        let strategy: PythonStrategy = PythonStrategy()
        let timeoutValue: Int = 1
        let request: ToolRequest = ToolRequest(
            name: "python_exec",
            arguments: """
            {
                "code": "import time\\ntime.sleep(10)",
                "timeout": \(timeoutValue)
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("timeout") == true)
    }
}
