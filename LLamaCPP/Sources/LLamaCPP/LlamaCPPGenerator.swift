import Abstractions
import Foundation
@preconcurrency import llama
#if DEBUG
import os.signpost
#endif

/// Generator for llama.cpp text generation
/// Note: This class is NOT thread-safe and should only be used within LlamaCPPSession actor
internal final class LlamaCPPGenerator {
    private let model: LlamaCPPModel
    private let context: LlamaCPPContext
    private let tokenizer: LlamaCPPTokenizer
    private var currentPosition: Int32 = 0
    private var samplerPointer: UnsafeMutablePointer<llama_sampler>?

    /// Initialize generator with model and context
    /// - Parameters:
    ///   - model: The loaded model
    ///   - context: The context for generation
    internal init(model: LlamaCPPModel, context: LlamaCPPContext) {
        self.model = model
        self.context = context
        self.tokenizer = LlamaCPPTokenizer()
    }

    /// Reset the generator state including position tracking
    internal func reset() {
        currentPosition = 0
        // Also reset the sampler if needed
        if let sampler = samplerPointer {
            llama_sampler_reset(sampler)
        }
        // Clear the memory/KV cache to ensure clean state
        if let ctx = context.pointer,
            let memory = llama_get_memory(ctx) {
            #if DEBUG
            SignpostInstrumentation.signposter.emitEvent(SignpostNames.kvCacheClear)
            #endif
            llama_memory_clear(memory, true)
        }
    }

    /// Free the sampler chain and release resources
    internal func free() {
        if let sampler = samplerPointer {
            llama_sampler_free(sampler)
            samplerPointer = nil
        }
        currentPosition = 0
    }

    deinit {
        // Free resources if not already freed
        if let sampler = samplerPointer {
            llama_sampler_free(sampler)
            samplerPointer = nil
        }
    }

    /// Generate next token from a text prompt
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - sampling: Optional sampling parameters
    /// - Returns: The generated token ID
    /// - Throws: LlamaCPPError if generation fails
    @inlinable
    internal func generateNextToken(
        prompt: String,
        sampling: SamplingParameters = .default
    ) throws -> Int32 {
        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }
        let tokens: [Int32] = try tokenizer.tokenize(text: prompt, addBos: true, modelPointer: ptr)
        return try generateNextToken(tokens: tokens, sampling: sampling)
    }

    /// Generate next token from token IDs
    /// - Parameters:
    ///   - tokens: Input token IDs (can be empty for continuation)
    ///   - sampling: Optional sampling parameters
    /// - Returns: The generated token ID
    /// - Throws: LlamaCPPError if generation fails
    @inlinable
    internal func generateNextToken(
        tokens: [Int32],
        sampling: SamplingParameters = .default
    ) throws -> Int32 {
        guard let ctx = context.pointer else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }

        guard model.pointer != nil else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }

        // Process input tokens if provided
        if !tokens.isEmpty {
            try processBatch(tokens: tokens)
        }

        // Get logits from the last position
        guard let logits = llama_get_logits(ctx) else {
            throw LLMError.providerError(code: "DECODE_FAILED", message: "Failed to decode tokens")
        }

        // Sample next token
        // NOTE: We do NOT process the generated token here!
        // It will be processed in the next call when it's passed as input.
        // This avoids double processing and improves performance by ~30%.
        return try sampleToken(logits, sampling: sampling)
    }

    /// Process a single token efficiently
    /// - Parameter token: The token to process
    /// - Throws: LlamaCPPError if processing fails
    @inline(__always)
    private func processSingleToken(_ token: Int32) throws {
        // For single tokens, just use the regular batch processing
        // which is already optimized when n=1
        try processBatch(tokens: [token])
    }

    /// Process a batch of tokens
    /// - Parameter tokens: The tokens to process
    /// - Throws: LlamaCPPError if processing fails
    @inline(__always)
    internal func processBatch(tokens: [Int32]) throws {
        guard let ctx = context.pointer else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }
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

        // Use llama_batch_get_one for single-sequence generation
        // This is optimized and handles position tracking automatically
        let batch: llama_batch = chunk.withUnsafeBufferPointer { buffer in
            llama_batch_get_one(
                UnsafeMutablePointer(mutating: buffer.baseAddress),
                tokenCount
            )
        }

        let result: Int32 = llama_decode(ctx, batch)
        if result != 0 {
            throw LLMError.providerError(code: "DECODE_FAILED", message: "Failed to decode tokens")
        }

        // Position is tracked automatically by llama_decode when batch.pos = NULL
        return tokenCount
    }

    /// Get logits for the current context state
    /// - Parameter prompt: The text prompt to process
    /// - Returns: Array of logits for all vocabulary tokens
    /// - Throws: LlamaCPPError if processing fails
    internal func getLogits(prompt: String) throws -> [Float] {
        guard let ctx = context.pointer else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }

        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }
        let tokens: [Int32] = try tokenizer.tokenize(text: prompt, addBos: true, modelPointer: ptr)
        try processBatch(tokens: tokens)

        guard let logitsPtr = llama_get_logits(ctx) else {
            throw LLMError.providerError(code: "DECODE_FAILED", message: "Failed to decode tokens")
        }

        let vocabSize: Int = Int(model.vocabSize)
        var logits: [Float] = []
        logits.reserveCapacity(vocabSize)

        for index in 0..<vocabSize {
            logits.append(logitsPtr[index])
        }

        return logits
    }

    @inline(__always)
    private func sampleToken(
        _: UnsafePointer<Float>,
        sampling: SamplingParameters
    ) throws -> Int32 {
        guard let ctx = context.pointer else {
            throw LLMError.invalidConfiguration("Context is not available")
        }

        // Create or update sampler chain
        if samplerPointer == nil {
            if let newChain = createSamplerChain(params: sampling) {
                samplerPointer = newChain
            }
        }

        guard let chain = samplerPointer else {
            throw LLMError.invalidConfiguration("Failed to create sampler chain")
        }

        // Sample using llama.cpp's native sampler
        // -1 means sample from the last token's logits
        let token: Int32 = llama_sampler_sample(chain, ctx, -1)

        // CRITICAL: Accept the token to update sampler state
        // This is required for repetition penalties, grammar, and other stateful sampling
        llama_sampler_accept(chain, token)

        return token
    }

    private func createSamplerChain(
        params: SamplingParameters
    ) -> UnsafeMutablePointer<llama_sampler>? {
        // Log sampling configuration
        Logger.logSamplingConfiguration(params)

        let chainParams: llama_sampler_chain_params = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(chainParams) else {
            return nil
        }

        if params.temperature <= 0 {
            addGreedySampler(to: chain)
        } else {
            addProbabilisticSamplers(to: chain, params: params)
        }

        return chain
    }

    private func addGreedySampler(to chain: UnsafeMutablePointer<llama_sampler>) {
        if let greedy = llama_sampler_init_greedy() {
            llama_sampler_chain_add(chain, greedy)
        }
    }

    private func addPenaltiesIfNeeded(
        to chain: UnsafeMutablePointer<llama_sampler>,
        params: SamplingParameters
    ) {
        let hasRepPenalty: Bool = params.repetitionPenalty != nil && params.repetitionPenalty != 1.0
        let hasFreqPenalty: Bool = params.frequencyPenalty != nil && params.frequencyPenalty != 0.0
        let hasPresPenalty: Bool = params.presencePenalty != nil && params.presencePenalty != 0.0
        let hasAnyPenalty: Bool = hasRepPenalty || hasFreqPenalty || hasPresPenalty

        guard hasAnyPenalty else {
            return
        }

        let defaultRange: Int32 = 64
        let lastN: Int32 = params.repetitionPenaltyRange.map { Int32($0) } ?? defaultRange
        let repPenalty: Float = params.repetitionPenalty ?? 1.0
        let freqPenalty: Float = params.frequencyPenalty ?? 0.0
        let presPenalty: Float = params.presencePenalty ?? 0.0

        if let penalties = llama_sampler_init_penalties(
            lastN,        // last n tokens to consider
            repPenalty,   // repetition penalty
            freqPenalty,  // frequency penalty
            presPenalty   // presence penalty
        ) {
            llama_sampler_chain_add(chain, penalties)
        }
    }

    private func addProbabilisticSamplers(
        to chain: UnsafeMutablePointer<llama_sampler>,
        params: SamplingParameters
    ) {
        // Add penalties if needed
        addPenaltiesIfNeeded(to: chain, params: params)

        // Add top-k if specified
        if let topKValue = params.topK,
            topKValue > 0,
            let topK = llama_sampler_init_top_k(Int32(topKValue)) {
            llama_sampler_chain_add(chain, topK)
        }

        // Add top-p if specified
        if params.topP < 1.0, let topP = llama_sampler_init_top_p(params.topP, 1) {
            llama_sampler_chain_add(chain, topP)
        }

        // Add temperature
        if let temp = llama_sampler_init_temp(params.temperature) {
            llama_sampler_chain_add(chain, temp)
        }

        // Add distribution sampler with seed if provided
        let seed: UInt32 = params.seed.map { UInt32($0) } ?? UInt32.random(in: 0..<UInt32.max)
        if let dist = llama_sampler_init_dist(seed) {
            llama_sampler_chain_add(chain, dist)
        }
    }
}
