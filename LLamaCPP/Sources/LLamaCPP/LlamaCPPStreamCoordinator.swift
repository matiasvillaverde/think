import Abstractions
import Foundation
#if DEBUG
import os.signpost
#endif

/// Coordinates the streaming generation process
internal struct LlamaCPPStreamCoordinator {
    internal let model: LlamaCPPModel
    internal let context: LlamaCPPContext
    internal let generator: LlamaCPPGenerator
    internal let shouldStop: () -> Bool

    internal struct PreparedStream {
        internal let promptTokens: [Int32]
        internal let state: GenerationState
        internal let maxTokens: Int
    }

    internal init(
        model: LlamaCPPModel,
        context: LlamaCPPContext,
        generator: LlamaCPPGenerator,
        shouldStop: @escaping () -> Bool
    ) {
        self.model = model
        self.context = context
        self.generator = generator
        self.shouldStop = shouldStop
    }

    /// Execute the full streaming pipeline
    internal func executeStream(
        input: LLMInput,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) throws {
        #if DEBUG
        let signpostID: OSSignpostID = SignpostInstrumentation.signposter.makeSignpostID()
        let streamState: OSSignpostIntervalState = SignpostInstrumentation.signposter.beginInterval(
            SignpostNames.streamGeneration,
            id: signpostID
        )
        defer {
            SignpostInstrumentation.signposter.endInterval(SignpostNames.streamGeneration, streamState)
        }
        #endif

        generator.reset()
        try processStream(input: input, continuation: continuation)
    }
}
