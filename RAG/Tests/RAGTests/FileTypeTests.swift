import Abstractions
import CoreGraphics
import Foundation
import NaturalLanguage
import PDFKit
@testable import Rag
import Testing

@Suite("File Type Support")
internal struct FileTypeTests {
    let rag: Rag?

    init() async throws {
        rag = try await TestHelpers.createTestRagIfAvailable()
    }

    @Test("JSON file processing")
    func testJSONProcessing() async throws {
        guard let rag else {
            return
        }
        let jsonContent: String = """
        {
            "title": "Machine Learning Concepts",
            "topics": [
                "Neural Networks",
                "Deep Learning",
                "Natural Language Processing"
            ],
            "difficulty": "intermediate"
        }
        """

        let fileURL: URL = try createFile(content: jsonContent, extension: "json")
        for try await progress in await rag.add(fileURL: fileURL) {
            #expect(progress.completedUnitCount > 0)
        }

        let results: [SearchResult] = try await rag.semanticSearch(
            query: "neural networks",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)
        #expect(results[0].text.contains("neural networks"))
    }

    @Test("CSV file processing")
    func testCSVProcessing() async throws {
        guard let rag else {
            return
        }
        let csvContent: String = """
        Name,Age,Occupation
        John Doe,30,Data Scientist
        Jane Smith,28,ML Engineer
        Bob Johnson,35,AI Researcher
        """

        let fileURL: URL = try createFile(content: csvContent, extension: "csv")

        let config: Configuration = Configuration(tokenUnit: .sentence)
        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: config) {
            #expect(progress.completedUnitCount > 0)
        }

        let results: [SearchResult] = try await rag.semanticSearch(
            query: "data scientist",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)
        print(results)
        #expect(results[0].text.contains("Data Scientist"))
    }

    @Test("Markdown file processing")
    func testMarkdownProcessing() async throws {
        guard let rag else {
            return
        }
        let markdownContent: String = """
        # AI Advances

        ## Recent Developments
        Transformers have revolutionized NLP tasks.

        ## Applications
        - Text Generation
        - Image Recognition
        - Speech Processing
        """

        let fileURL: URL = try createFile(content: markdownContent, extension: "md")
        for try await progress in await rag.add(fileURL: fileURL) {
            #expect(progress.completedUnitCount > 0)
        }

        let results: [SearchResult] = try await rag.semanticSearch(
            query: "transformers NLP",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )
        #expect(!results.isEmpty)
        #expect(results[0].text.contains("transformers"))
    }

    @Test("DOCX files report unsupported operation")
    func testDocxProcessingUnsupported() async throws {
        guard let rag else {
            return
        }
        let docxContent: String = "DOCX placeholder content"
        let fileURL: URL = try createFile(content: docxContent, extension: "docx")

        await #expect(throws: FileProcessor.FileProcessorError.unsupportedOperation("docx")) {
            for try await _ in await rag.add(fileURL: fileURL) {
                // Expecting an error before any progress is emitted.
            }
        }
    }
}

@Suite("Database Persistence")
internal struct DatabasePersistenceTests {
    let tempDBPath: String = FileManager.default.temporaryDirectory.appendingPathComponent("test.db").path

    @Test("Persist and reload database")
    func testDatabasePersistence() async throws {
        guard TestHelpers.isLocalModelAvailable else {
            return
        }
        // First session: Create and populate database
        let rag1: Rag = try await TestHelpers.createTestRag(database: .uri(tempDBPath))

        let content: String = "Specific test content for persistence verification."
        let fileURL: URL = try createFile(content: content, extension: "txt")

        for try await progress in await rag1.add(fileURL: fileURL) {
            #expect(progress.completedUnitCount > 0)
        }

        // Second session: Verify data persists
        let rag2: Rag = try await TestHelpers.createTestRag(database: .uri(tempDBPath))
        let results: [SearchResult] = try await rag2.semanticSearch(
            query: "persistence verification",
            numResults: 1,
            threshold: 10.0
        )

        #expect(!results.isEmpty)
        #expect(results[0].text.contains("persistence verification"))
    }
}

@Suite("Processing Strategies")
internal struct ProcessingStrategyTests {
    let rag: Rag?

    init() async throws {
        rag = try await TestHelpers.createTestRagIfAvailable()
    }

    @Test("Extract keywords strategy")
    func testKeywordExtraction() async throws {
        guard let rag else {
            return
        }
        let content: String = "The quick brown fox jumps over the lazy dog while practicing agility training."
        let fileURL: URL = try createFile(content: content, extension: "txt")

        for try await progress in await rag.add(fileURL: fileURL) {
            #expect(progress.completedUnitCount > 0)
        }
        let results: [SearchResult] = try await rag.semanticSearch(
            query: "fox agility",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )

        #expect(!results.isEmpty)
        #expect(!results[0].keywords.isEmpty)
        #expect(results[0].keywords.contains("fox"))
        #expect(results[0].keywords.contains("jumps"))
    }

    @Test("Full text strategy")
    func testFullTextStrategy() async throws {
        guard let rag else {
            return
        }
        let content: String = "The quick brown fox jumps over the lazy dog."
        let fileURL: URL = try createFile(content: content, extension: "txt")

        let config: Configuration = Configuration(strategy: .fullText)
        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: config) {
            #expect(progress.completedUnitCount > 0)
        }

        let results: [SearchResult] = try await rag.semanticSearch(
            query: "fox jump",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )

        #expect(!results.isEmpty)
        #expect(results[0].keywords.isEmpty)
    }
}

@Suite("Tokenization Units")
internal struct TokenizationTests {
    let rag: Rag?

    init() async throws {
        rag = try await TestHelpers.createTestRagIfAvailable()
    }

    @Test("Sentence tokenization")
    func testSentenceTokenization() async throws {
        guard let rag else {
            return
        }
        let content: String = """
        Neural networks are powerful. Inspired by the structure of the human brain, they can recognize patterns,
        classify information, and make highly accurate predictions. Convolutional neural networks (CNNs) have
        transformed computer vision, enabling facial recognition, image classification, and object detection.
        Meanwhile, recurrent neural networks (RNNs) and transformers have enhanced natural language
        processing (NLP), making AI-driven chatbots and language translation systems more effective.
        """
        let fileURL: URL = try createFile(content: content, extension: "txt")

        let config: Configuration = Configuration(tokenUnit: .sentence)
        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: config) {
            #expect(progress.completedUnitCount > 0)
        }

        let results: [SearchResult] = try await rag.semanticSearch(
            query: "neural networks",
            numResults: 1,
            threshold: 10.0,
            table: "embeddings"
        )

        #expect(!results.isEmpty)
        #expect(results[0].text == "neural networks are powerful.")
    }
}

@Suite("Real World Scenarios")
internal struct RealWorldTests {
    let rag: Rag?

    init() async throws {
        rag = try await TestHelpers.createTestRagIfAvailable()
    }

    @Test("Technical documentation search")
    func testTechnicalDocSearch() async throws {
        guard let rag else {
            return
        }
        let content: String = """
        HTTP Status Codes:
        200 OK - Standard response for successful HTTP requests
        201 Created - Request has been fulfilled, new resource created
        404 Not Found - Requested resource could not be found
        500 Internal Server Error - Generic server error message
        """

        let fileURL: URL = try createFile(content: content, extension: "txt")
        let config: Configuration = Configuration(tokenUnit: .sentence)
        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: config) {
            #expect(progress.completedUnitCount > 0)
        }

        let results: [SearchResult] = try await rag.semanticSearch(
            query: "What happens when a resource is not found?",
            numResults: 1,
            threshold: 10.0
        )

        #expect(!results.isEmpty)
        #expect(results[0].text.contains("404"))
        #expect(results[0].text.contains("not found"))
    }

    @Test("Research paper abstract search")
    func testResearchPaperSearch() async throws {
        guard let rag else {
            return
        }
        let content: String = """
        Title: Advances in Transformer Architecture

        Abstract:
        This paper presents a novel approach to transformer architecture
        that reduces computational complexity from O(n²) to O(n log n).
        Our method maintains accuracy while significantly improving performance
        on large-scale language tasks. Experimental results show a 40%
        reduction in training time without loss of model quality.
        """

        let fileURL: URL = try createFile(content: content, extension: "txt")
        let config: Configuration = Configuration(tokenUnit: .document)
        for try await progress in await rag.add(fileURL: fileURL, id: UUID(), configuration: config) {
            #expect(progress.completedUnitCount > 0)
        }

        let results: [SearchResult] = try await rag.semanticSearch(
            query: "transformer performance improvements",
            numResults: 1,
            threshold: 10.0
        )

        #expect(!results.isEmpty)
        #expect(results[0].text.contains("computational complexity"))
        #expect(results[0].text.contains("improving performance"))
    }
}

// Helper Functions
private func createFile(content: String, extension: String) throws -> URL {
    let tempDir: URL = FileManager.default.temporaryDirectory
    let fileURL: URL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(`extension`)
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
}
