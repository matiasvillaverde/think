import Foundation
import NaturalLanguage
@testable import Rag
import Testing

@Suite("RagTokenizer")
internal struct RagTokenizerTests {
    @Test("Tokenize lowercases and strips punctuation")
    func testTokenizeNormalizesTokens() {
        let text: String = "Hello, WORLD! 2024."

        let tokens: [String] = RagTokenizer().tokenize(text, using: .word)

        #expect(tokens == ["hello", "world", "2024"])
    }

    @Test("Tokenize skips whitespace-only input")
    func testTokenizeSkipsWhitespace() {
        let tokens: [String] = RagTokenizer().tokenize("  \n\t  ", using: .word)

        #expect(tokens.isEmpty)
    }

    @Test("Extract keywords filters conjunctions")
    func testExtractKeywordsFiltersConjunctions() {
        let keywords: String = RagTokenizer().extractKeywords(from: "Cats and dogs run quickly.")
        let keywordSet: Set<String> = Set(keywords.split(separator: " ").map(String.init))

        #expect(keywordSet.contains("cats"))
        #expect(keywordSet.contains("dogs"))
        #expect(!keywordSet.contains("and"))
    }
}
