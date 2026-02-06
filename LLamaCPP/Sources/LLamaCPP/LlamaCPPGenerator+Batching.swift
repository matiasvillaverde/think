import Abstractions
import Foundation
@preconcurrency import llama

extension LlamaCPPGenerator {
    /// Process a batch of tokens
    /// - Parameter tokens: The tokens to process
    /// - Throws: LlamaCPPError if processing fails
    @inline(__always)
    internal func processBatch(tokens: [Int32]) throws {
        guard let ctx = context.pointer else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }

        syncWithContextResetIfNeeded()

        guard !tokens.isEmpty else {
            return
        }

        let batchLimit: Int = max(1, Int(context.batchSize))
        try processTokensInBatches(tokens, batchLimit: batchLimit, ctx: ctx)
    }

    private func processTokensInBatches(
        _ tokens: [Int32],
        batchLimit: Int,
        ctx: OpaquePointer
    ) throws {
        var offset: Int = 0
        while offset < tokens.count {
            let end: Int = min(offset + batchLimit, tokens.count)
            let tokenCount: Int32 = try decodeBatch(tokens[offset..<end], ctx: ctx)
            currentPosition += tokenCount
            offset = end
        }
    }

    private func decodeBatch(
        _ tokens: ArraySlice<Int32>,
        ctx: OpaquePointer
    ) throws -> Int32 {
        let chunk: [Int32] = Array(tokens)
        let tokenCount: Int32 = Int32(chunk.count)
        guard tokenCount > 0 else {
            return 0
        }

        let result: Int32 = chunk.withUnsafeBufferPointer { buffer in
            var batch: llama_batch = llama_batch_get_one(
                UnsafeMutablePointer(mutating: buffer.baseAddress),
                tokenCount
            )
            batch.n_tokens = tokenCount
            return llama_decode(ctx, batch)
        }

        guard result == 0 else {
            throw LLMError.providerError(code: "DECODE_FAILED", message: "Failed to decode tokens")
        }
        return tokenCount
    }
}
