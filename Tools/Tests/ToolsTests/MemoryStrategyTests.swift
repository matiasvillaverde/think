@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("MemoryStrategy Tests")
internal struct MemoryStrategyTests {
    @Test("MemoryStrategy has correct tool definition")
    func testToolDefinition() {
        // Given
        let strategy: MemoryStrategy = MemoryStrategy { _ in .success(UUID()) }

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "memory")
        #expect(definition.description.contains("persistent memory"))
        #expect(definition.schema.contains("type"))
        #expect(definition.schema.contains("content"))
    }

    @Test("MemoryStrategy writes long-term memory successfully")
    func testWriteLongTermMemory() async {
        // Given
        var capturedRequest: MemoryWriteRequest?
        let strategy: MemoryStrategy = MemoryStrategy { request in
            capturedRequest = request
            return .success(UUID())
        }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "type": "longTerm",
                "content": "User prefers dark mode",
                "keywords": ["preferences", "theme"]
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("saved successfully"))
        #expect(capturedRequest != nil)
        #expect(capturedRequest?.type == .longTerm)
        #expect(capturedRequest?.content == "User prefers dark mode")
        #expect(capturedRequest?.keywords.contains("preferences") == true)
    }

    @Test("MemoryStrategy writes daily memory successfully")
    func testWriteDailyMemory() async {
        // Given
        var capturedRequest: MemoryWriteRequest?
        let strategy: MemoryStrategy = MemoryStrategy { request in
            capturedRequest = request
            return .success(UUID())
        }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "type": "daily",
                "content": "Discussed project requirements"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(capturedRequest?.type == .daily)
        #expect(capturedRequest?.content == "Discussed project requirements")
    }

    @Test("MemoryStrategy handles missing type parameter")
    func testMissingType() async {
        // Given
        let strategy: MemoryStrategy = MemoryStrategy { _ in .success(UUID()) }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "content": "Some content"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("type") == true)
    }

    @Test("MemoryStrategy handles missing content parameter")
    func testMissingContent() async {
        // Given
        let strategy: MemoryStrategy = MemoryStrategy { _ in .success(UUID()) }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "type": "longTerm"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("content") == true)
    }

    @Test("MemoryStrategy handles invalid type parameter")
    func testInvalidType() async {
        // Given
        let strategy: MemoryStrategy = MemoryStrategy { _ in .success(UUID()) }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "type": "invalid",
                "content": "Some content"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("Invalid memory type") == true)
    }

    @Test("MemoryStrategy handles write callback failure")
    func testWriteFailure() async {
        // Given
        let testError: NSError = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Database error"]
        )
        let strategy: MemoryStrategy = MemoryStrategy { _ in .failure(testError) }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "type": "longTerm",
                "content": "Some content"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("Failed to save memory") == true)
    }

    @Test("MemoryStrategy handles empty content")
    func testEmptyContent() async {
        // Given
        let strategy: MemoryStrategy = MemoryStrategy { _ in .success(UUID()) }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "type": "longTerm",
                "content": ""
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("content") == true)
    }

    @Test("MemoryStrategy handles malformed JSON")
    func testMalformedJSON() async {
        // Given
        let strategy: MemoryStrategy = MemoryStrategy { _ in .success(UUID()) }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: "not valid json",
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("Invalid JSON") == true)
    }

    @Test("MemoryStrategy accepts alternative type formats")
    func testAlternativeTypeFormats() async {
        // Given - Test "long_term" variant
        var capturedType: MemoryType?
        let strategy: MemoryStrategy = MemoryStrategy { request in
            capturedType = request.type
            return .success(UUID())
        }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "type": "long_term",
                "content": "Test content"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(capturedType == .longTerm)
    }

    @Test("MemoryStrategy response includes memory ID")
    func testResponseIncludesMemoryId() async {
        // Given
        let expectedId: UUID = UUID()
        let strategy: MemoryStrategy = MemoryStrategy { _ in .success(expectedId) }
        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: """
            {
                "type": "longTerm",
                "content": "Test"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains(expectedId.uuidString))
    }
}
