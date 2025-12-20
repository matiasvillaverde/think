import Abstractions
import Foundation

/// Helper methods for LlamaCPPStreamHandler
internal enum LlamaCPPStreamHandlerHelpers {
    internal static func logCompletionIfNeeded(
        metrics: ChunkMetrics,
        stopReason: GenerationMetrics.StopReason?
    ) {
        guard let usage = metrics.usage,
            let reason = stopReason else { return }

        let tps: Double? = metrics.timing?.tokensPerSecond(tokenCount: usage.generatedTokens)
        Logger.generationCompleted(
            generatedTokens: usage.generatedTokens,
            tokensPerSecond: tps,
            stopReason: stopReasonString(reason)
        )
    }

    internal static func stopReasonString(_ reason: GenerationMetrics.StopReason) -> String {
        switch reason {
        case .endOfSequence:
            return "EOS"

        case .maxTokens:
            return "max_tokens"

        case .stopSequence:
            return "stop_sequence"

        default:
            return "unknown"
        }
    }

    internal static func determineStopReason(
        context: LlamaCPPStreamHandler.Context,
        shouldStop: Bool
    ) -> GenerationMetrics.StopReason {
        if shouldStop {
            return .userRequested
        }
        if context.state.generatedTokenCount >= context.maxTokens {
            return .maxTokens
        }
        if context.lastToken == context.eosToken {
            return .endOfSequence
        }
        if context.stopSequences.contains(where: { context.buffer.hasSuffix($0) }) {
            return .stopSequence
        }
        return .endOfSequence
    }
}
