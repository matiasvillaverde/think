import Abstractions
import Foundation
@testable import Rag
import Testing

extension DeletionAndGlobalSearchTests {
    func setupTablesForConcurrentTest(tables: [String], contents: [String]) async throws {
        for (table, content) in zip(tables, contents) {
            let fileURL: URL = try createTextFile(with: content)
            let config: Configuration = Configuration(table: table)
            for try await progress in await rag.add(fileURL: fileURL, configuration: config) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: content,
                numResults: Constants.Search.defaultResultCount,
                threshold: Constants.Search.defaultThreshold,
                table: table
            )
            #expect(!results.isEmpty, "Content should be added to table \(table)")
        }
    }

    func getTable1ContentForConcurrentTest() async throws -> String? {
        let initialResults: [SearchResult] = try await rag.semanticSearch(
            query: "AI",
            numResults: Constants.Search.defaultResultCount,
            threshold: Constants.Search.defaultThreshold,
            table: "table1"
        )
        #expect(initialResults.count == 1, "Should find table1's content")

        let allResults: [SearchResult] = try await rag.semanticSearchEverywhere(
            query: "AI ML NLP",
            numResults: Constants.Search.maxResultCount,
            threshold: Constants.Search.defaultThreshold
        )
        #expect(allResults.count == Constants.Testing.expectedTotalResults, "Should have 3 results initially")

        return initialResults.first?.text
    }

    func verifyConcurrentOperations() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await rag.deleteTable("table1")
            }

            group.addTask {
                let results: [SearchResult] = try await rag.semanticSearchEverywhere(
                    query: "AI ML NLP",
                    numResults: Constants.Search.maxResultCount,
                    threshold: Constants.Search.defaultThreshold
                )
                #expect(!results.isEmpty, "Should find some results during concurrent operations")
            }

            try await group.waitForAll()
        }
    }

    func verifyConcurrentTestResults(tables: [String], table1Content: String?) async throws {
        try await Task.sleep(nanoseconds: Constants.Testing.concurrentTestSleepNanoseconds)

        let finalResults: [SearchResult] = try await rag.semanticSearchEverywhere(
            query: "AI ML NLP",
            numResults: Constants.Search.maxResultCount,
            threshold: Constants.Search.defaultThreshold
        )
        #expect(
            finalResults.count == Constants.Testing.expectedResultsAfterDeletion,
            "Should have exactly 2 results after table1 deletion"
        )

        if let table1Content {
            for result in finalResults {
                #expect(result.text != table1Content, "Results should not contain content from deleted table1")
            }
        }

        for table in tables.dropFirst() {
            let results: [SearchResult] = try await rag.semanticSearch(
                query: "Content",
                numResults: Constants.Search.defaultResultCount,
                threshold: Constants.Search.defaultThreshold,
                table: table
            )
            #expect(!results.isEmpty, "Table \(table) should still contain content")
        }
    }

    func createTextFile(with text: String) throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
        let textURL: URL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        try text.write(to: textURL, atomically: true, encoding: .utf8)
        return textURL
    }
}
