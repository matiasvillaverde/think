import Abstractions
import Foundation

/// Metrics data collected during text generation
internal struct MetricsData {
    let generationStartTime: ContinuousClock.Instant
    let promptStartTime: ContinuousClock.Instant
    let promptEndTime: ContinuousClock.Instant
    let firstTokenTime: ContinuousClock.Instant?
    let promptTokenCount: Int
    let generatedTokenCount: Int
    let stopReason: GenerationMetrics.StopReason
    let parameters: GenerateParameters
}

/// Context for token processing operations
internal struct TokenContext {
    let state: GenerationState
    let context: ModelContext
    let input: LLMInput
    let continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    let clock: ContinuousClock
}

/// Context for generation operations
internal struct GenerationContext {
    let modelContext: ModelContext
    let input: LLMInput
    let parameters: GenerateParameters
    let generationStartTime: ContinuousClock.Instant
    let continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    let clock: ContinuousClock
}
