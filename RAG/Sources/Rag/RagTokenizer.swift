import Abstractions
import Foundation
import NaturalLanguage

// MARK: - RagTokenizer

internal struct RagTokenizer {
    func extractKeywords(from text: String) -> String {
        var keywords: [String] = [String]()
        let tagger: NLTagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, tokenRange in
            if let tag,
                [.noun, .verb, .adjective, .adverb].contains(tag) {
                keywords.append(String(text[tokenRange]).lowercased())
            }
            return true
        }

        return keywords.joined(separator: " ")
    }

    func tokenize(_ text: String, using unit: NLTokenUnit) -> [String] {
        // Handle empty or whitespace-only text
        guard !text.isEmpty else {
            return []
        }

        // Setup tokenizer
        let tokenizer: NLTokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text

        // Pre-allocate array capacity (estimate based on average token length)
        var tokens: [String] = [String]()
        tokens.reserveCapacity(text.count / Constants.averageTokenLength)

        tokenizer.enumerateTokens(
            in: text.startIndex..<text.endIndex
        ) { tokenRange, _ in
            let token: String = String(text[tokenRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .illegalCharacters)
                .lowercased()
            if !token.isEmpty {
                tokens.append(token)
            }
            return true
        }

        return tokens
    }

    func tokenizeAndChunk(
        _ text: String,
        using unit: NLTokenUnit,
        chunking: ChunkingConfiguration
    ) -> [String] {
        let tokens: [String] = tokenize(text, using: unit)
        return chunkTokens(tokens, chunking: chunking)
    }

    func chunkTokens(
        _ tokens: [String],
        chunking: ChunkingConfiguration
    ) -> [String] {
        guard !tokens.isEmpty else {
            return []
        }

        let maxTokens: Int = max(1, chunking.maxTokens)
        let overlap: Int = min(max(0, chunking.overlap), maxTokens - 1)

        guard maxTokens < tokens.count else {
            return tokens
        }

        var chunks: [String] = []
        chunks.reserveCapacity((tokens.count / maxTokens) + 1)

        var startIndex: Int = 0
        while startIndex < tokens.count {
            let endIndex: Int = min(startIndex + maxTokens, tokens.count)
            let chunkTokens: ArraySlice<String> = tokens[startIndex..<endIndex]
            chunks.append(chunkTokens.joined(separator: " "))

            if endIndex == tokens.count {
                break
            }

            startIndex = endIndex - overlap
        }

        return chunks
    }
}
