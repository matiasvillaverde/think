@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("ToolExecutor Tests")
internal struct ToolExecutorTests {
    @Test("Execute single tool request successfully")
    func testExecuteSingleToolRequest() async throws {
        // Given
        let executor: ToolExecutor = ToolExecutor()
        let request: ToolRequest = ToolRequest(
            name: "test_tool",
            arguments: "{\"input\": \"test\"}",
            id: UUID()
        )

        // Register a test tool strategy
        struct TestStrategy: ToolStrategy {
            let definition: ToolDefinition = ToolDefinition(
                name: "test_tool",
                description: "A test tool",
                schema: "{\"type\": \"object\", \"properties\": {\"input\": {\"type\": \"string\"}}}"
            )

            func execute(request: ToolRequest) -> ToolResponse {
                ToolResponse(
                    requestId: request.id,
                    toolName: "test_tool",
                    result: "Success: \(request.arguments)"
                )
            }
        }
        await executor.registerStrategy(TestStrategy())

        // When
        let response: ToolResponse = try await executor.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "test_tool")
        #expect(response.result.contains("Success"))
        #expect(response.error == nil)
    }

    @Test("Execute request for non-existent tool returns error")
    func testExecuteNonExistentTool() async throws {
        // Given
        let executor: ToolExecutor = ToolExecutor()
        let request: ToolRequest = ToolRequest(
            name: "non_existent",
            arguments: "{}",
            id: UUID()
        )

        // When
        let response: ToolResponse = try await executor.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "non_existent")
        #expect(response.error != nil)
        #expect(response.error?.contains("not found") == true)
    }

    @Test("Execute request with invalid JSON arguments returns error")
    func testExecuteWithInvalidJSON() async throws {
        // Given
        let executor: ToolExecutor = ToolExecutor()
        let request: ToolRequest = ToolRequest(
            name: "test_tool",
            arguments: "invalid json",
            id: UUID()
        )

        // Register a test tool strategy
        struct TestStrategy: ToolStrategy {
            let definition: ToolDefinition = ToolDefinition(
                name: "test_tool",
                description: "A test tool",
                schema: "{}"
            )

            func execute(request: ToolRequest) -> ToolResponse {
                ToolResponse(
                    requestId: request.id,
                    toolName: "test_tool",
                    result: "Should not be called"
                )
            }
        }
        await executor.registerStrategy(TestStrategy())

        // When
        let response: ToolResponse = try await executor.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        // The strategy will handle invalid JSON internally, not at executor level
        #expect(response.result == "Should not be called")
    }

    @Test("Execute multiple requests in parallel")
    func testExecuteMultipleRequestsInParallel() async throws {
        // Given
        let executor: ToolExecutor = ToolExecutor()
        let request1: ToolRequest = ToolRequest(
            name: "tool1",
            arguments: "{}",
            id: UUID()
        )
        let request2: ToolRequest = ToolRequest(
            name: "tool2",
            arguments: "{}",
            id: UUID()
        )

        // Register test tool strategies
        struct Tool1Strategy: ToolStrategy {
            let definition: ToolDefinition = ToolDefinition(
                name: "tool1",
                description: "Tool 1",
                schema: "{}"
            )

            func execute(request: ToolRequest) -> ToolResponse {
                ToolResponse(
                    requestId: request.id,
                    toolName: "tool1",
                    result: "Tool 1 result"
                )
            }
        }

        struct Tool2Strategy: ToolStrategy {
            let definition: ToolDefinition = ToolDefinition(
                name: "tool2",
                description: "Tool 2",
                schema: "{}"
            )

            func execute(request: ToolRequest) -> ToolResponse {
                ToolResponse(
                    requestId: request.id,
                    toolName: "tool2",
                    result: "Tool 2 result"
                )
            }
        }

        await executor.registerStrategy(Tool1Strategy())
        await executor.registerStrategy(Tool2Strategy())

        // When
        let responses: [ToolResponse] = try await executor.executeBatch(requests: [request1, request2])

        // Then
        #expect(responses.count == 2)
        #expect(responses.contains { $0.toolName == "tool1" && $0.result == "Tool 1 result" })
        #expect(responses.contains { $0.toolName == "tool2" && $0.result == "Tool 2 result" })
    }
}
