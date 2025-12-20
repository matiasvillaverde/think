import Abstractions
import NaturalLanguage
@testable import Rag
import Testing

@Suite("Chunking")
internal struct ChunkingTests {
    @Test("Tokenize and chunk applies overlap")
    func testTokenizeAndChunkWithOverlap() {
        let text: String = "One two three four five six"
        let chunking: ChunkingConfiguration = ChunkingConfiguration(maxTokens: 3, overlap: 1)

        let chunks: [String] = RagTokenizer().tokenizeAndChunk(
            text,
            using: .word,
            chunking: chunking
        )

        #expect(chunks == ["one two three", "three four five", "five six"])
    }

    @Test("Chunking disabled returns raw tokens")
    func testChunkingDisabledReturnsTokens() {
        let text: String = "One two three"

        let chunks: [String] = RagTokenizer().tokenizeAndChunk(
            text,
            using: .word,
            chunking: .disabled
        )

        #expect(chunks == ["one", "two", "three"])
    }

    @Test("Chunking handles empty input")
    func testChunkingEmptyInput() {
        let chunks: [String] = RagTokenizer().tokenizeAndChunk(
            "",
            using: .word,
            chunking: .fileDefault
        )

        #expect(chunks.isEmpty)
    }

    @Test("Chunking respects clamped overlap")
    func testChunkingClampedOverlap() {
        let chunking: ChunkingConfiguration = ChunkingConfiguration(maxTokens: 2, overlap: 10)
        let chunks: [String] = RagTokenizer().chunkTokens(
            ["a", "b", "c"],
            chunking: chunking
        )

        #expect(chunks == ["a b", "b c"])
    }
}
