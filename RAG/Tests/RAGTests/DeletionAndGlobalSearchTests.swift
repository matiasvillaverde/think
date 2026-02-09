import Abstractions
import CoreGraphics
import Foundation
import NaturalLanguage
import PDFKit
@testable import Rag
import Testing

// MARK: - Deletion and Global Search Tests

@Suite("Deletion and Global Search Operations")
internal struct DeletionAndGlobalSearchTests {
    let rag: Rag?

    init() async throws {
        rag = try await TestHelpers.createTestRagIfAvailable()
    }

    @Test("Basic deletion by ID")
    func testBasicDeletion() async throws {
        guard let rag else {
            return
        }
        // Setup test data
        let content: String = "This is a test document for deletion."
        let id: UUID = UUID()
        let fileURL: URL = try createTextFile(with: content)

        // Add content and verify it exists
        for try await progress in await rag.add(fileURL: fileURL, id: id) {
            #expect(progress.completedUnitCount > 0)
        }
        var results: [SearchResult] = try await rag.semanticSearch(
            query: "test document",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)

        // Delete content and verify it's gone
        try await rag.delete(id: id)
        results = try await rag.semanticSearch(
            query: "test document",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(results.isEmpty)
    }

    @Test("Delete non-existent ID")
    func testDeleteNonExistentId() async throws {
        guard let rag else {
            return
        }
        let nonExistentId: UUID = UUID()
        // Should not throw but return successfully
        try await rag.delete(id: nonExistentId)
    }

    @Test("Delete ID with multiple chunks")
    func testDeleteIdWithMultipleChunks() async throws {
        guard let rag else {
            return
        }
        let id: UUID = UUID()
        var largeContent: String = ""
        for chunkNumber in 0..<1_000 {
            largeContent += "Chunk \(chunkNumber): This is a test sentence with specific content. "
        }

        let fileURL: URL = try createTextFile(with: largeContent)
        for try await progress in await rag.add(fileURL: fileURL, id: id) {
            #expect(progress.completedUnitCount > 0)
        }

        // Verify content exists
        var results: [SearchResult] = try await rag.semanticSearch(
            query: "test sentence",
            numResults: 5,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)

        // Delete and verify all chunks are removed
        try await rag.delete(id: id)
        results = try await rag.semanticSearch(
            query: "test sentence",
            numResults: 5,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(results.isEmpty)
    }

    @Test("Delete table operations")
    func testDeleteTable() async throws {
        guard let rag else {
            return
        }
        // Setup test data in custom table
        let content: String = "This is a test document in a custom table."
        let fileURL: URL = try createTextFile(with: content)
        let customTable: String = "custom_table"

        let config: Configuration = Configuration(table: customTable)
        for try await progress in await rag.add(fileURL: fileURL, configuration: config) {
            #expect(progress.completedUnitCount > 0)
        }

        // Verify content exists
        var results: [SearchResult] = try await rag.semanticSearch(
            query: "test document",
            numResults: 1,
            threshold: 10.0,
            table: customTable
        )
        #expect(!results.isEmpty)

        // Delete table and verify it's gone
        try await rag.deleteTable(customTable)

        do {
            results = try await rag.semanticSearch(
                query: "test document",
                numResults: 1,
                threshold: 10.0,
                table: customTable
            )
            #expect(Bool(false), "Should have thrown an error for deleted table")
        } catch {
            #expect(Bool(true), "Successfully caught deleted table error")
        }
    }

    @Test("Delete non-existent table")
    func testDeleteNonExistentTable() async {
        guard let rag else {
            return
        }
        do {
            try await rag.deleteTable("non_existent_table")
        } catch {
            #expect(Bool(true), "Successfully caught non-existent table error")
        }
    }

    @Test("Delete all tables operation")
    func testDeleteAll() async throws {
        guard let rag else {
            return
        }
        // Setup test data in multiple tables
        let tables: [String] = ["table1", "table2", "table3", Abstractions.Constants.defaultTable]
        let content: String = "This is a new document."

        // Add content to tables
        for table in tables {
            let fileURL: URL = try createTextFile(with: content)
            let config: Configuration = Configuration(table: table)
            for try await progress in await rag.add(fileURL: fileURL, configuration: config) {
                #expect(progress.completedUnitCount > 0)
            }
        }

        // Verify content exists in all tables
        for table in tables {
            let results: [SearchResult] = try await rag.semanticSearch(
                query: "test document",
                numResults: 1,
                threshold: 10.0,
                table: table
            )
            #expect(!results.isEmpty, "Table \(table) should contain test document")
        }

        // Delete all tables
        try await rag.deleteAll()

        // Try to add new content - this should succeed since database is reinitialized
        let newContent: String = "This is a new document after reset."
        let newFileURL: URL = try createTextFile(with: newContent)
        for try await progress in await rag.add(fileURL: newFileURL) {
            #expect(progress.completedUnitCount > 0)
        }

        // Search in default table should work
        let results: [SearchResult] = try await rag.semanticSearch(
            query: "new document",
            numResults: 3,
            threshold: 10.0
        )
        #expect(!results.isEmpty, "Should be able to find content after database reset")
        #expect(results[0].text.contains("new document"), "Should find the newly added content")
    }

    @Test("Semantic search everywhere basic functionality")
    func testSemanticSearchEverywhereBasic() async throws {
        guard let rag else {
            return
        }
        // Setup test data in multiple tables
        let tables: [String] = ["table1", "table2"]
        let contents: [String] = [
            "This is a document about artificial intelligence.",
            "This is a document about machine learning."
        ]

        for (table, content) in zip(tables, contents) {
            let fileURL: URL = try createTextFile(with: content)
            let config: Configuration = Configuration(table: table)
            for try await progress in await rag.add(fileURL: fileURL, configuration: config) {
                #expect(progress.completedUnitCount > 0)
            }
        }

        // Test search across all tables
        let results: [SearchResult] = try await rag.semanticSearchEverywhere(
            query: "AI and ML",
            numResults: 5,
            threshold: 10.0
        )

        #expect(results.count == 2)
        #expect(results.contains { $0.text.contains("artificial intelligence") })
        #expect(results.contains { $0.text.contains("machine learning") })
    }

    @Test("Semantic search everywhere with empty tables")
    func testSemanticSearchEverywhereEmpty() async throws {
        guard let rag else {
            return
        }
        let results: [SearchResult] = try await rag.semanticSearchEverywhere(
            query: "test query",
            numResults: 5,
            threshold: 10.0
        )
        #expect(results.isEmpty)
    }

    @Test("Semantic search everywhere with large dataset")
    func testSemanticSearchEverywhereLargeDataset() async throws {
        guard let rag else {
            return
        }
        let tables: [String] = ["table1", "table2", "table3"]
        let contentTemplate: String = "This is document %d about topic %d in table %@."

        // Add 1000 documents across multiple tables
        for table in tables {
            for documentIndex in 0..<33 {
                let content: String = String(format: contentTemplate, documentIndex, documentIndex % 10, table)
                let fileURL: URL = try createTextFile(with: content)
                let config: Configuration = Configuration(table: table)
                for try await progress in await rag.add(fileURL: fileURL, configuration: config) {
                    #expect(progress.completedUnitCount > 0)
                }
            }
        }

        // Test search with different result limits
        let results1: [SearchResult] = try await rag.semanticSearchEverywhere(
            query: "topic 5",
            numResults: 10,
            threshold: 10.0
        )
        #expect(!results1.isEmpty)
        #expect(results1.count <= 10)

        let results2: [SearchResult] = try await rag.semanticSearchEverywhere(
            query: "topic 5",
            numResults: 100,
            threshold: 10.0
        )
        #expect(results2.count > results1.count)
    }

    @Test("Complex operations sequence")
    func testComplexOperationsSequence() async throws {
        guard let rag else {
            return
        }
        // 1. Setup initial data across multiple tables
        let tables: [String] = ["table1", "table2"]
        let id: UUID = UUID()

        for table in tables {
            let content: String = "This is a test document with ID \(id) in table \(table)."
            let fileURL: URL = try createTextFile(with: content)
            for try await progress in await rag.add(
                fileURL: fileURL,
                id: id,
                configuration: Configuration(table: table)
            ) {
                #expect(progress.completedUnitCount > 0)
            }
        }

        // 2. Verify content exists in all tables
        var results: [SearchResult] = try await rag.semanticSearchEverywhere(
            query: "test document",
            numResults: 5,
            threshold: 10.0
        )
        #expect(results.count == 2)

        // 3. Delete specific ID from one table
        try await rag.delete(id: id, table: tables[0])

        // 4. Verify content only exists in remaining table
        results = try await rag.semanticSearchEverywhere(
            query: "test document",
            numResults: 5,
            threshold: 10.0
        )
        #expect(results.count == 1)

        // 5. Delete entire table
        try await rag.deleteTable(tables[1])

        // 6. Verify no content remains
        results = try await rag.semanticSearchEverywhere(
            query: "test document",
            numResults: 5,
            threshold: 10.0
        )
        #expect(results.isEmpty)
    }

    @Test("Concurrent operations")
    func testConcurrentOperations() async throws {
        guard let rag else {
            return
        }
        let tables: [String] = ["table1", "table2", "table3"]
        let contents: [String] = ["Content about AI", "Content about ML", "Content about NLP"]

        try await setupTablesForConcurrentTest(rag: rag, tables: tables, contents: contents)
        let table1Content: String? = try await getTable1ContentForConcurrentTest(rag: rag)
        try await verifyConcurrentOperations(rag: rag)
        try await verifyConcurrentTestResults(rag: rag, tables: tables, table1Content: table1Content)
    }
}
