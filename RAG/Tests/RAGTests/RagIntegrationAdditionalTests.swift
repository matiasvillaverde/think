import Abstractions
import Foundation
@testable import Rag
import Testing

@Suite("Additional RAG Integration")
internal struct RagIntegrationAdditionalTests {
    let rag: Rag

    init() async throws {
        rag = try await TestHelpers.createTestRag()
    }

    @Test("Adding empty text creates no chunks")
    func testAddEmptyTextProducesNoResults() async throws {
        for try await progress in await rag.add(text: "", id: UUID()) {
            #expect(progress.completedUnitCount > 0)
        }

        await #expect(throws: RagDatabase.Error.chunkNotFound) {
            _ = try await rag.getChunk(index: 1)
        }
    }

    @Test("Unsupported file extensions are rejected")
    func testUnsupportedFileTypeThrows() async throws {
        let fileURL: URL = try TestHelpers.createTempFile(content: "unsupported", fileExtension: "foo")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await #expect(throws: Rag.RagError.unsupportedFileType) {
            for try await _ in await rag.add(fileURL: fileURL) {
                // Expecting unsupported file type before any progress is emitted.
            }
        }
    }

    @Test("Table isolation keeps results scoped")
    func testTableIsolation() async throws {
        let customTable: String = "custom_table_isolation"
        let fileURL: URL = try TestHelpers.createTempFile(
            content: "Unique token for custom table",
            fileExtension: "txt"
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let config: Configuration = Configuration(table: customTable)
        for try await progress in await rag.add(fileURL: fileURL, configuration: config) {
            #expect(progress.completedUnitCount > 0)
        }

        let defaultResults: [SearchResult] = try await rag.semanticSearch(
            query: "unique token",
            numResults: 1,
            threshold: 10.0
        )
        #expect(defaultResults.isEmpty)

        let customResults: [SearchResult] = try await rag.semanticSearch(
            query: "unique token",
            numResults: 1,
            threshold: 10.0,
            table: customTable
        )
        #expect(!customResults.isEmpty)
    }
}
