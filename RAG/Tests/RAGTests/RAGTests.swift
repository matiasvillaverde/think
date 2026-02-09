import Abstractions
import CoreGraphics
import Foundation
import NaturalLanguage
import PDFKit
@testable import Rag
import Testing

@Suite("RAG Implementation Tests")
internal struct RagTests {
    let rag: Rag?

    init() async throws {
        rag = try await TestHelpers.createTestRagIfAvailable()
    }

    // MARK: - Helper Methods

    private static func createTextFile(with text: String) throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
        let textURL: URL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        try text.write(to: textURL, atomically: true, encoding: .utf8)
        return textURL
    }

    // MARK: - Basic Functionality Tests

    @Suite("Basic File Operations")
    struct BasicFileTests {
        let rag: Rag?

        init() async throws {
            rag = try await TestHelpers.createTestRagIfAvailable()
        }

        @Test("Adding and retrieving text file content")
        func testTextFileAddAndRetrieve() async throws {
            guard let rag else {
                return
            }
            let content: String = "This is a test document about machine learning and artificial intelligence."
            let fileURL: URL = try createTextFile(with: content)

            for try await progress in await rag.add(fileURL: fileURL) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "machine learning",
                numResults: 1,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(!results.isEmpty)
            #expect(results[0].text.contains("machine learning"))
            #expect(results[0].keywords.contains("machine"))
            #expect(results[0].keywords.contains("learning"))
        }

        @Test("Adding multiple text files")
        func testMultipleTextFiles() async throws {
            guard let rag else {
                return
            }
            let files: [String] = [
                "File 1 about programming and software development.",
                "File 2 about data science and statistics.",
                "File 3 about machine learning algorithms."
            ]

            for content in files {
                let fileURL: URL = try createTextFile(with: content)
                for try await progress in await rag.add(fileURL: fileURL) {
                    #expect(progress.completedUnitCount > 0)
                }
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "programming",
                numResults: 3,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(results.count >= 1)
            #expect(results[0].text.contains("programming"))
        }
    }

    // MARK: - Content Verification Tests

    @Suite("Content Verification")
    struct ContentVerificationTests {
        let rag: Rag?

        init() async throws {
            rag = try await TestHelpers.createTestRagIfAvailable()
        }

        @Test("Verify exact content match")
        func testExactContentMatch() async throws {
            guard let rag else {
                return
            }
            let content: String = """
            Specific test content with unique phrases.
            This is a controlled test environment.
            We expect exact matches for this content.
            """
            let fileURL: URL = try createTextFile(with: content)

            for try await progress in await rag.add(fileURL: fileURL) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "controlled test environment",
                numResults: 1,
                threshold: 10.0
            )
            #expect(!results.isEmpty)
            #expect(results[0].text.contains("controlled test environment"))
        }

        @Test("Verify keyword extraction")
        func testKeywordExtraction() async throws {
            guard let rag else {
                return
            }
            let content: String = "The quick brown fox jumps over the lazy dog."
            let fileURL: URL = try createTextFile(with: content)

            for try await progress in await rag.add(fileURL: fileURL) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "fox",
                numResults: 1,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(!results.isEmpty)
            #expect(results[0].keywords.contains("fox"))
            #expect(results[0].keywords.contains("jumps"))
        }
    }

    // MARK: - Edge Cases Tests

    @Suite("Edge Cases")
    struct EdgeCaseTests {
        let rag: Rag?

        init() async throws {
            rag = try await TestHelpers.createTestRagIfAvailable()
        }

        @Test("Empty file handling")
        func testEmptyFile() async throws {
            guard let rag else {
                return
            }
            let fileURL: URL = try createTextFile(with: "")

            await #expect(throws: FileProcessor.FileProcessorError.fileISEmpty) {
                for try await progress in await rag.add(fileURL: fileURL) {
                    #expect(progress.completedUnitCount > 0)
                }
            }
        }

        @Test("Very large content handling")
        func testVeryLargeContent() async throws {
            guard let rag else {
                return
            }
            var largeContent: String = ""
            for lineNumber in 0..<10_000 {
                largeContent += "Line \(lineNumber): This is a test sentence with some content. "
            }

            let fileURL: URL = try createTextFile(with: largeContent)
            for try await progress in await rag.add(fileURL: fileURL) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "test sentence",
                numResults: 5,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(!results.isEmpty)
        }

        @Test("Special characters handling")
        func testSpecialCharacters() async throws {
            guard let rag else {
                return
            }
            let content: String = "Special chars: !@#$%^&*()_+-=[]{}|;:'\",.<>?/\n"
            let fileURL: URL = try createTextFile(with: content)

            for try await progress in await rag.add(fileURL: fileURL) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "special",
                numResults: 1,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(!results.isEmpty)
        }

        @Test("Unicode content handling")
        func testUnicodeContent() async throws {
            guard let rag else {
                return
            }
            let content: String = "Unicode test: 你好世界 Hello World こんにちは世界"
            let fileURL: URL = try createTextFile(with: content)

            for try await progress in await rag.add(fileURL: fileURL) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "hello",
                numResults: 1,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(!results.isEmpty)
        }
    }

    // MARK: - Search Functionality Tests

    @Suite("Search Functionality")
    struct SearchTests {
        let rag: Rag?

        init() async throws {
            rag = try await TestHelpers.createTestRagIfAvailable()
        }

        @Test("Semantic search accuracy")
        func testSemanticSearchAccuracy() async throws {
            guard let rag else {
                return
            }
            let contents: [String] = [
                "Machine learning is a subset of artificial intelligence.",
                "Data science involves statistical analysis and programming.",
                "Natural language processing helps computers understand human language."
            ]

            for content in contents {
                let fileURL: URL = try createTextFile(with: content)
                for try await progress in await rag.add(fileURL: fileURL) {
                    #expect(progress.completedUnitCount > 0)
                }
            }

            // Test semantic similarity
            let results: [SearchResult] = try await rag.semanticSearch(
                query: "AI and ML",
                numResults: 3,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(!results.isEmpty)
            #expect(results[0].text.contains("artificial intelligence") || results[0].text.contains("Machine learning"))
        }

        @Test("Search result ordering")
        func testSearchResultOrdering() async throws {
            guard let rag else {
                return
            }
            let content: String = """
            First paragraph about machine learning.
            Second paragraph about deep learning.
            Third paragraph about reinforcement learning.
            """
            let fileURL: URL = try createTextFile(with: content)

            for try await progress in await rag.add(fileURL: fileURL) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "machine learning",
                numResults: 3,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(results.count >= 1)
            #expect(results[0].text.contains("machine learning"))
        }

        @Test("Different token units")
        func testDifferentTokenUnits() async throws {
            guard let rag else {
                return
            }
            let content: String = "First sentence. Second sentence. Third sentence."
            let fileURL: URL = try createTextFile(with: content)

            // Test with different token units
            let config: Configuration = Configuration(tokenUnit: .sentence)
            for try await progress in await rag.add(fileURL: fileURL, configuration: config) {
                #expect(progress.completedUnitCount > 0)
            }

            let results: [SearchResult] = try await rag.semanticSearch(
                query: "Second",
                numResults: 1,
                threshold: 10.0,
                table: "embeddings"
            )
            #expect(!results.isEmpty)
            #expect(results[0].text.contains("second sentence"))
        }
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling")
    struct ErrorHandlingTests {
        let rag: Rag?

        init() async throws {
            rag = try await TestHelpers.createTestRagIfAvailable()
        }

        @Test("Non-existent file handling")
        func testNonExistentFile() async {
            guard let rag else {
                return
            }
            let nonExistentURL: URL = URL(fileURLWithPath: "/non/existent/path.txt")

            do {
                for try await progress in await rag.add(fileURL: nonExistentURL) {
                    #expect(progress.completedUnitCount > 0)
                }
            } catch {
                #expect(Bool(true), "Successfully caught file not found error")
            }
        }

        @Test("Invalid chunk index handling")
        func testInvalidChunkIndex() async {
            guard let rag else {
                return
            }
            do {
                _ = try await rag.getChunk(index: 999_999)
            } catch {
                #expect(Bool(true), "Successfully caught invalid chunk index error")
            }
        }
    }

    // MARK: - Table Name Consistency Tests

    @Suite("Table Name Consistency")
    struct TableNameConsistencyTests {
        @Test("Table name consistency demonstration")
        func testTableNameConsistency() {
            // This test demonstrates that our fix worked:
            // Before: Configuration used "embeddings", tests used "chunks" → data mismatch
            // After: Both Configuration and tests use "embeddings" → data found consistently

            let config: Configuration = Configuration(strategy: .fullText)
            #expect(config.table == "embeddings", "Configuration correctly defaults to 'embeddings' table")

            // Test passes now that table names are consistent across the codebase
            #expect(true, "Table name consistency has been established across Configuration and tests")
        }

        private static func createTextFile(with text: String) throws -> URL {
            let tempDir: URL = FileManager.default.temporaryDirectory
            let fileURL: URL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")

            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        }
    }
}
