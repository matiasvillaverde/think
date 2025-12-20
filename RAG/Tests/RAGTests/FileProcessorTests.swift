import Abstractions
import Foundation
import NaturalLanguage
@testable import Rag
import Testing

@Suite("File Processor")
internal struct FileProcessorTests {
    @Test("Process text yields progress and chunk metadata")
    func testProcessTextYieldsChunkMetadata() async throws {
        let processor: FileProcessor = FileProcessor()
        let chunking: ChunkingConfiguration = ChunkingConfiguration(maxTokens: 2, overlap: 0)
        let text: String = "Cats run dogs play"

        var progressSnapshots: [Progress] = []
        var collectedChunks: [ChunkData] = []

        for try await (chunks, progress) in processor.processTextAsync(
            text,
            tokenUnit: .word,
            chunking: chunking,
            strategy: .extractKeywords
        ) {
            progressSnapshots.append(progress)
            collectedChunks.append(contentsOf: chunks)
        }

        let progress: Progress = try #require(progressSnapshots.first)
        #expect(progress.totalUnitCount > 0)
        #expect(progress.completedUnitCount == progress.totalUnitCount)

        let sortedChunks: [ChunkData] = collectedChunks.sorted { $0.localChunkIndex < $1.localChunkIndex }
        #expect(sortedChunks.map(\.localChunkIndex) == [0, 1])
        #expect(sortedChunks.map(\.text) == ["cats run", "dogs play"])
        #expect(sortedChunks.allSatisfy { $0.pageIndex == 0 })

        let keywordTokens: Set<String> = Set(
            sortedChunks
                .first?.keywords
                .split(separator: " ")
                .map(String.init) ?? []
        )
        #expect(keywordTokens.contains("cats"))
        #expect(keywordTokens.contains("run"))
    }

    @Test("Full text strategy skips keyword extraction")
    func testFullTextStrategySkipsKeywords() async throws {
        let processor: FileProcessor = FileProcessor()
        let chunking: ChunkingConfiguration = ChunkingConfiguration(maxTokens: 2, overlap: 0)
        let text: String = "Cats run dogs play"

        var collectedChunks: [ChunkData] = []

        for try await (chunks, _) in processor.processTextAsync(
            text,
            tokenUnit: .word,
            chunking: chunking,
            strategy: .fullText
        ) {
            collectedChunks.append(contentsOf: chunks)
        }

        let allKeywordsEmpty: Bool = collectedChunks.allSatisfy(\.keywords.isEmpty)

        #expect(!collectedChunks.isEmpty)
        #expect(allKeywordsEmpty)
    }

    @Test("Invalid JSON format throws error")
    func testInvalidJSONFormatThrows() async throws {
        let fileURL: URL = try TestHelpers.createTempFile(content: "[\"a\", \"b\"]", fileExtension: "json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let stream: AsyncThrowingStream<([ChunkData], Progress), Error> = try FileProcessor().processFile(
            fileURL,
            fileType: .json,
            tokenUnit: .word,
            chunking: .disabled,
            strategy: .fullText
        )

        await #expect(throws: FileProcessor.FileProcessorError.invalidJSONFormat) {
            for try await _ in stream {
                // Expecting failure before any chunks are yielded.
            }
        }
    }

    @Test("CSV processing ignores empty lines")
    func testCSVProcessingIgnoresEmptyLines() async throws {
        let csvContent: String = """
        Name,Age,Occupation

        Alice,30,Engineer

        Bob,25,Designer
        """
        let fileURL: URL = try TestHelpers.createTempFile(content: csvContent, fileExtension: "csv")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let stream: AsyncThrowingStream<([ChunkData], Progress), Error> = try FileProcessor().processFile(
            fileURL,
            fileType: .csv,
            tokenUnit: .word,
            chunking: ChunkingConfiguration(maxTokens: 1, overlap: 0),
            strategy: .fullText
        )

        var collectedChunks: [ChunkData] = []
        for try await (chunks, _) in stream {
            collectedChunks.append(contentsOf: chunks)
        }

        let texts: [String] = collectedChunks.map(\.text)
        #expect(texts.count == 3)
        #expect(texts.contains("Name,Age,Occupation"))
        #expect(texts.contains("Alice,30,Engineer"))
        #expect(texts.contains("Bob,25,Designer"))
    }
}
