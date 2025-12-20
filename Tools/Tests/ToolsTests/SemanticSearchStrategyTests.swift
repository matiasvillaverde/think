@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("SemanticSearchStrategy Tests")
internal struct SemanticSearchStrategyTests {
    @Test("SemanticSearchStrategy has correct tool definition with files")
    func testToolDefinitionWithFiles() {
        // Given
        let fileTitles: [String] = ["document1.txt", "document2.pdf", "report.docx"]
        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: MockDatabase(),
            chatId: UUID(),
            fileTitles: fileTitles
        )

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "semantic_search")
        #expect(definition.description.contains("semantic search"))
        #expect(definition.description.contains("Available files: document1.txt, document2.pdf, report.docx"))
        #expect(definition.description.contains("Use this tool to search for specific information"))
        #expect(definition.schema.contains("query"))
    }

    @Test("SemanticSearchStrategy shows all files without truncation")
    func testToolDefinitionShowsAllFiles() {
        // Given - many files
        let fileTitles: [String] = [
            "file1.txt", "file2.pdf", "file3.docx",
            "file4.md", "file5.csv", "file6.json",
            "file7.xml", "file8.html", "file9.swift",
            "file10.py"
        ]
        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: MockDatabase(),
            chatId: UUID(),
            fileTitles: fileTitles
        )

        // When
        let definition: ToolDefinition = strategy.definition

        // Then - all files should be listed
        #expect(definition.description.contains("file1.txt"))
        #expect(definition.description.contains("file10.py"))
        #expect(definition.description.contains("Available files:"))
        // Should not contain truncation indicators
        #expect(!definition.description.contains("and"))
        #expect(!definition.description.contains("more"))
        #expect(!definition.description.contains("total"))
    }

    @Test("SemanticSearchStrategy handles empty file list")
    func testToolDefinitionWithNoFiles() {
        // Given
        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: MockDatabase(),
            chatId: UUID(),
            fileTitles: []
        )

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "semantic_search")
        #expect(definition.description.contains("No files currently attached"))
        #expect(definition.schema.contains("query"))
    }

    @Test("SemanticSearchStrategy executes search with valid query")
    func testExecuteSearchWithValidQuery() async {
        // Given
        let mockDatabase: MockDatabase = MockDatabase()
        let chatId: UUID = UUID()
        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: mockDatabase,
            chatId: chatId,
            fileTitles: ["test.txt"]
        )

        let request: ToolRequest = ToolRequest(
            name: "semantic_search",
            arguments: """
            {
                "query": "test query",
                "resultCount": \(ToolConstants.defaultSearchResultCount),
                "threshold": \(ToolConstants.defaultSemanticSearchThreshold)
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "semantic_search")
        #expect(response.error == nil)
        #expect(response.result.contains("results"))
    }

    @Test("SemanticSearchStrategy uses chat table naming")
    func testExecuteSearchUsesChatTableName() async {
        let mockDatabase: MockDatabase = MockDatabase()
        let chatId: UUID = UUID()
        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: mockDatabase,
            chatId: chatId,
            fileTitles: ["test.txt"]
        )

        let request: ToolRequest = ToolRequest(
            name: "semantic_search",
            arguments: "{\"query\": \"table check\"}",
            id: UUID()
        )

        _ = await strategy.execute(request: request)

        let lastCall: MockDatabase.SemanticSearchCall? = await mockDatabase.lastSemanticSearchCall
        #expect(lastCall?.table == RagTableName.chatTableName(chatId: chatId))
    }

    @Test("SemanticSearchStrategy forwards search parameters")
    func testExecuteSearchForwardsParameters() async {
        let mockDatabase: MockDatabase = MockDatabase()
        let chatId: UUID = UUID()
        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: mockDatabase,
            chatId: chatId,
            fileTitles: ["test.txt"]
        )

        let expectedCount: Int = 4
        let expectedThreshold: Double = 2.5

        let request: ToolRequest = ToolRequest(
            name: "semantic_search",
            arguments: """
            {
                "query": "parameter check",
                "resultCount": \(expectedCount),
                "threshold": \(expectedThreshold)
            }
            """,
            id: UUID()
        )

        _ = await strategy.execute(request: request)

        let lastCall: MockDatabase.SemanticSearchCall? = await mockDatabase.lastSemanticSearchCall
        #expect(lastCall?.query == "parameter check")
        #expect(lastCall?.numResults == expectedCount)
        #expect(lastCall?.threshold == expectedThreshold)
    }

    @Test("SemanticSearchStrategy handles missing query parameter")
    func testExecuteSearchWithMissingQuery() async {
        // Given
        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: MockDatabase(),
            chatId: UUID(),
            fileTitles: []
        )

        let request: ToolRequest = ToolRequest(
            name: "semantic_search",
            arguments: "{}",
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("query") == true)
    }

    @Test("SemanticSearchStrategy uses default parameters")
    func testExecuteSearchWithDefaults() async {
        // Given
        let strategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: MockDatabase(),
            chatId: UUID(),
            fileTitles: ["document.txt"]
        )

        let request: ToolRequest = ToolRequest(
            name: "semantic_search",
            arguments: "{\"query\": \"test\"}",
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        // Should use default resultCount and threshold
        #expect(response.result.contains("\(ToolConstants.defaultSemanticSearchResults) results"))
    }
}
