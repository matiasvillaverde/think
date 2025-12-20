import Abstractions
import Foundation
import llama

/// Wrapper for llama.cpp tokenizer functionality
internal struct LlamaCPPTokenizer {
    private static let tokenBufferMultiplier: Int32 = 4
    private static let tokenBufferPadding: Int32 = 10
    private static let pieceBufferSize: Int = 256

    /// Tokenize text into tokens
    /// - Parameters:
    ///   - text: The text to tokenize
    ///   - addBos: Whether to add beginning-of-sequence token
    ///   - modelPointer: The model pointer to use for tokenization
    /// - Returns: Array of token IDs
    /// - Throws: LlamaCPPError if tokenization fails
    internal func tokenize(
        text: String,
        addBos: Bool,
        modelPointer: OpaquePointer
    ) throws -> [Int32] {
        let vocab: OpaquePointer = try getVocab(from: modelPointer)
        let maxTokens: Int32 = calculateMaxTokens(for: text)
        var tokens: [Int32] = Array(repeating: 0, count: Int(maxTokens))

        let tokenCount: Int32 = performTokenization(
            vocab: vocab,
            text: text,
            tokens: &tokens,
            maxTokens: maxTokens,
            addBos: addBos
        )

        try validateTokenCount(tokenCount)
        return Array(tokens.prefix(Int(tokenCount)))
    }

    private func getVocab(from modelPointer: OpaquePointer) throws -> OpaquePointer {
        guard let vocab = llama_model_get_vocab(modelPointer) else {
            throw LLMError.providerError(
                code: "TOKENIZE_FAILED",
                message: "Failed to tokenize text"
            )
        }
        return vocab
    }

    private func validateTokenCount(_ tokenCount: Int32) throws {
        if tokenCount < 0 {
            throw LLMError.providerError(
                code: "TOKENIZE_FAILED",
                message: "Failed to tokenize text"
            )
        }
    }

    private func calculateMaxTokens(for text: String) -> Int32 {
        Int32(text.count) * Self.tokenBufferMultiplier + Self.tokenBufferPadding
    }

    private func performTokenization(
        vocab: OpaquePointer,
        text: String,
        tokens: inout [Int32],
        maxTokens: Int32,
        addBos: Bool
    ) -> Int32 {
        tokens.withUnsafeMutableBufferPointer { buffer in
            llama_tokenize(
                vocab,
                text,
                Int32(text.count),
                buffer.baseAddress,
                maxTokens,
                addBos,
                false // special tokens
            )
        }
    }

    /// Detokenize tokens back to text
    /// - Parameters:
    ///   - tokens: Array of token IDs
    ///   - modelPointer: The model pointer to use for detokenization
    /// - Returns: The detokenized text
    /// - Throws: LlamaCPPError if detokenization fails
    @inlinable
    internal func detokenize(tokens: [Int32], modelPointer: OpaquePointer) throws -> String {
        guard let vocab = llama_model_get_vocab(modelPointer) else {
            throw LLMError.providerError(
                code: "DECODE_FAILED",
                message: "Failed to decode tokens"
            )
        }

        var result: String = ""
        for token in tokens {
            let piece: String = tokenToString(token: token, vocab: vocab)
            result += piece
        }

        return result
    }

    /// Convert a single token to its string representation
    /// - Parameters:
    ///   - token: The token ID
    ///   - vocab: The vocabulary pointer
    /// - Returns: String representation of the token
    /// - Throws: LlamaCPPError if conversion fails
    internal func tokenToString(token: Int32, vocab: OpaquePointer) -> String {
        let bufferSize: Int = Self.pieceBufferSize
        var buffer: [CChar] = Array(repeating: 0, count: bufferSize)

        let length: Int32 = getTokenPiece(
            vocab: vocab,
            token: token,
            buffer: &buffer,
            bufferSize: bufferSize
        )

        if length < 0 {
            // Return empty string for special tokens that can't be decoded
            return ""
        }

        if length == 0 {
            // Empty token
            return ""
        }

        // Safely convert buffer to string
        let data: Data = Data(bytes: buffer, count: Int(length))
        guard let result = String(data: data, encoding: .utf8) else {
            // If UTF-8 decode fails, return empty string instead of throwing
            return ""
        }
        return result
    }

    private func getTokenPiece(
        vocab: OpaquePointer,
        token: Int32,
        buffer: inout [CChar],
        bufferSize: Int
    ) -> Int32 {
        buffer.withUnsafeMutableBufferPointer { bufferPointer in
            llama_token_to_piece(
                vocab,
                token,
                bufferPointer.baseAddress,
                Int32(bufferSize),
                0,
                false // special tokens
            )
        }
    }

    /// Get the beginning-of-sequence token
    /// - Parameter modelPointer: The model pointer
    /// - Returns: The BOS token ID, or -1 if not available
    internal func bosToken(modelPointer: OpaquePointer) -> Int32 {
        guard let vocab = llama_model_get_vocab(modelPointer) else {
            return -1
        }
        return llama_vocab_bos(vocab)
    }

    /// Get the end-of-sequence token
    /// - Parameter modelPointer: The model pointer
    /// - Returns: The EOS token ID, or -1 if not available
    internal func eosToken(modelPointer: OpaquePointer) -> Int32 {
        guard let vocab = llama_model_get_vocab(modelPointer) else {
            return -1
        }
        return llama_vocab_eos(vocab)
    }
}
