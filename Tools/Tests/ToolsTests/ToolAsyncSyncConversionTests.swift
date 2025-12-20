@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("Tool Async/Sync Conversion Tests")
internal struct ToolAsyncSyncConversionTests {
    @Test("Async ToolStrategy execute method is properly converted to sync")
    func testAsyncToSyncConversion() async {
        // Given
        let mockDatabase: MockDatabase = MockDatabase()
        let chatId: UUID = UUID()
        let fileTitles: [String] = ["test.txt"]

        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: mockDatabase,
            chatId: chatId,
            fileTitles: fileTitles
        )

        let request: ToolRequest = ToolRequest(
            name: "semantic_search",
            arguments: """
            {
                "query": "test query",
                "resultCount": 3
            }
            """,
            id: UUID()
        )

        // When - Call the async method directly
        let response: ToolResponse = await strategy.execute(request: request)

        // Then - Should complete without hanging or errors
        #expect(response.requestId == request.id)
        #expect(response.toolName == "semantic_search")
        // MockDatabase should return empty results
        #expect(response.result.contains("Found") || response.result.contains("No results"))
    }

    @Test("Sync ToolStrategy methods work correctly with ToolExecutor")
    func testSyncMethodsWithExecutor() async throws {
        // Given
        let executor: ToolExecutor = ToolExecutor()
        await executor.registerStrategy(FunctionsStrategy())

        let request: ToolRequest = ToolRequest(
            name: "functions",
            arguments: """
            {
                "function_name": "calculate_sum",
                "parameters": {
                    "a": 10,
                    "b": 5
                }
            }
            """,
            id: UUID()
        )

        // When - Execute through ToolExecutor (which handles async/sync conversion)
        let response: ToolResponse = try await executor.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "functions")
        #expect(response.error == nil)
        #expect(response.result.contains("Result: 15"))
    }

    @Test("Mixed async and sync strategies work together in parallel execution")
    func testMixedStrategiesParallelExecution() async throws {
        // Given
        let executor: ToolExecutor = ToolExecutor()
        await executor.registerStrategy(FunctionsStrategy()) // Sync strategy

        let mockDatabase: MockDatabase = MockDatabase()
        let semanticStrategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: mockDatabase,
            chatId: UUID(),
            fileTitles: ["test.txt"]
        )
        await executor.registerStrategy(semanticStrategy) // Async strategy

        let syncRequest: ToolRequest = ToolRequest(
            name: "functions",
            arguments: "{\"function_name\": \"get_timestamp\"}",
            id: UUID()
        )

        let asyncRequest: ToolRequest = ToolRequest(
            name: "semantic_search",
            arguments: "{\"query\": \"test\"}",
            id: UUID()
        )

        // When - Execute both requests in parallel
        let responses: [ToolResponse] = try await executor.executeBatch(
            requests: [syncRequest, asyncRequest]
        )

        // Then
        #expect(responses.count == 2)

        let syncResponse: ToolResponse? = responses.first { $0.requestId == syncRequest.id }
        let asyncResponse: ToolResponse? = responses.first { $0.requestId == asyncRequest.id }

        #expect(syncResponse != nil)
        #expect(asyncResponse != nil)
        #expect(syncResponse?.error == nil)
        #expect(asyncResponse?.error == nil)
        #expect(syncResponse?.result.contains("timestamp") == true)
    }
}
