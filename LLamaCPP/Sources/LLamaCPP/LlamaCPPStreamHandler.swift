import Abstractions
import Foundation
#if DEBUG
import os
#endif
#if DEBUG
import os.signpost
#endif

/// Handles streaming operations for LlamaCPP
internal enum LlamaCPPStreamHandler {
    internal struct Context {
        internal var state: GenerationState
        internal let maxTokens: Int
        internal let eosToken: Int32
        internal let stopSequences: [String]
        internal var buffer: String
        internal var lastToken: Int32?
    }

    internal struct Dependencies {
        internal let generator: LlamaCPPGenerator
        internal let tokenizer: LlamaCPPTokenizer
        internal let modelPointer: OpaquePointer
        internal let continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    }

    @inlinable
    internal static func processNextToken(
        deps: Dependencies,
        input: LLMInput,
        context: inout Context
    ) throws -> Bool {
        try Task.checkCancellation()

        if let lastToken = context.lastToken {
            try deps.generator.processBatch(tokens: [lastToken])
        }

        #if DEBUG
        // Only emit event for first token (TTFT) and every 100th token to avoid overhead
        if context.state.generatedTokenCount == 0 || context.state.generatedTokenCount.isMultiple(of: 100) {
            SignpostInstrumentation.signposter.emitEvent(SignpostNames.tokenGeneration)
        }
        #endif

        let tokenId: Int32 = try generateToken(deps: deps, input: input)
        context.lastToken = tokenId
        context.state.recordTokenGenerated()

        if tokenId == context.eosToken {
            return true
        }

        return try processGeneratedToken(
            tokenId: tokenId,
            deps: deps,
            context: &context
        )
    }

    @inline(__always)
    private static func generateToken(
        deps: Dependencies,
        input: LLMInput
    ) throws -> Int32 {
        try deps.generator.generateNextToken(
            tokens: [],
            sampling: input.sampling
        )
    }

    @inline(__always)
    private static func processGeneratedToken(
        tokenId: Int32,
        deps: Dependencies,
        context: inout Context
    ) throws -> Bool {
        let text: String = try deps.tokenizer.detokenize(
            tokens: [tokenId],
            modelPointer: deps.modelPointer
        )

        // Accumulate text in buffer
        context.buffer += text
        logDebugToken(context: context, text: text)

        // Check for complete stop sequences
        if let stopSeq = findStopSequence(in: context.buffer, sequences: context.stopSequences) {
            #if DEBUG
            // `Logger.debug` takes an escaping autoclosure; avoid capturing the `inout` context.
            let bufferLength: Int = context.buffer.count
            os.Logger(subsystem: "LLamaCPP", category: "StreamHandler")
                .debug(
                    "Stop sequence: \(stopSeq, privacy: .public) len=\(bufferLength, privacy: .public)"
                )
            #endif
            handleStopSequence(stopSeq, context: &context, deps: deps)
            return true
        }

        // Emit text that we're sure isn't part of a stop sequence
        emitSafeText(context: &context, deps: deps)
        return false
    }

    @inline(__always)
    private static func logDebugToken(context: Context, text: String) {
        #if DEBUG
        let debugTokenLimit: Int = 5
        if context.state.generatedTokenCount < debugTokenLimit {
            let tokenNum: Int = context.state.generatedTokenCount
            os.Logger(subsystem: "LLamaCPP", category: "StreamHandler")
                .debug(
                    "Token \(tokenNum, privacy: .public): '\(text, privacy: .public)'"
                )
        }
        #endif
    }

    @inline(__always)
    private static func handleStopSequence(
        _ stopSeq: String,
        context: inout Context,
        deps: Dependencies
    ) {
        // Find and remove stop sequence and everything after it
        if let range = context.buffer.range(of: stopSeq) {
            context.buffer = String(context.buffer[..<range.lowerBound])
        }
        Logger.stopSequenceDetected(sequence: stopSeq)

        // Emit any remaining text
        if !context.buffer.isEmpty {
            emitBufferedText(
                &context.state,
                text: context.buffer,
                continuation: deps.continuation
            )
            context.buffer = ""
        }
    }

    @inline(__always)
    private static func emitSafeText(
        context: inout Context,
        deps: Dependencies
    ) {
        // Find the longest safe prefix that can't be part of a stop sequence
        let safeLength: Int = findSafeTextLength(
            context.buffer,
            stopSequences: context.stopSequences
        )

        if safeLength > 0 {
            let safeText: String = String(context.buffer.prefix(safeLength))
            emitBufferedText(
                &context.state,
                text: safeText,
                continuation: deps.continuation
            )
            context.buffer = String(context.buffer.dropFirst(safeLength))
        }
    }

    @inline(__always)
    private static func findSafeTextLength(
        _ buffer: String,
        stopSequences: [String]
    ) -> Int {
        guard !buffer.isEmpty else {
            return 0
        }
        var minSafeLength: Int = buffer.count

        for sequence in stopSequences {
            if sequence.hasPrefix(buffer) {
                return 0
            }
            let safeLen: Int = computeSafeLength(buffer: buffer, sequence: sequence)
            minSafeLength = min(minSafeLength, safeLen)
        }
        return minSafeLength
    }

    private static func computeSafeLength(buffer: String, sequence: String) -> Int {
        // Don't check for overlaps if the sequence is just one character
        // Otherwise we'd never emit text when stop sequence is "\n"
        guard sequence.count > 1 else {
            return buffer.count
        }
        let maxOverlap: Int = min(buffer.count, sequence.count - 1)
        guard maxOverlap > 0 else {
            return buffer.count
        }

        for overlap in (1...maxOverlap).reversed() {
            let bufIdx: String.Index = buffer.index(buffer.endIndex, offsetBy: -overlap)
            let seqIdx: String.Index = sequence.index(sequence.startIndex, offsetBy: overlap)
            if buffer[bufIdx...] == sequence[..<seqIdx] {
                return buffer.count - overlap
            }
        }
        return buffer.count
    }

    @inline(__always)
    private static func findStopSequence(in buffer: String, sequences: [String]) -> String? {
        for sequence in sequences where buffer.contains(sequence) {
            return sequence
        }
        return nil
    }

    @inline(__always)
    private static func emitBufferedText(
        _ state: inout GenerationState,
        text: String,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) {
        guard !text.isEmpty else {
            return
        }

        let metrics: ChunkMetrics = state.buildMetrics()

        // Log time to first token (important UX metric)
        if state.generatedTokenCount == 1, let ttft = metrics.timing?.timeToFirstToken {
            let attosecondsToSeconds: Double = 1e18
            let ttftSeconds: Double = Double(ttft.components.seconds) +
                Double(ttft.components.attoseconds) / attosecondsToSeconds
            Logger.timeToFirstToken(duration: ttftSeconds)
        }

        continuation.yield(
            LLMStreamChunk(
                text: text,
                event: .text,
                metrics: metrics
            )
        )
    }

    internal static func sendFinishedEvent(
        context: Context,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation,
        shouldStop: Bool
    ) {
        let result: (GenerationState, ChunkMetrics) = buildFinalMetrics(
            context: context,
            shouldStop: shouldStop
        )
        let finalMetrics: ChunkMetrics = result.1
        let stopReason: GenerationMetrics.StopReason? = finalMetrics.generation?.stopReason
        LlamaCPPStreamHandlerHelpers.logCompletionIfNeeded(metrics: finalMetrics, stopReason: stopReason)

        continuation.yield(
            LLMStreamChunk(
                text: "",
                event: .finished,
                metrics: finalMetrics
            )
        )
    }

    private static func buildFinalMetrics(
        context: Context,
        shouldStop: Bool
    ) -> (GenerationState, ChunkMetrics) {
        var finalState: GenerationState = context.state
        let stopReason: GenerationMetrics.StopReason = LlamaCPPStreamHandlerHelpers.determineStopReason(
            context: context,
            shouldStop: shouldStop
        )
        finalState.recordStopReason(stopReason)
        let finalMetrics: ChunkMetrics = finalState.buildMetrics()
        return (finalState, finalMetrics)
    }
}
