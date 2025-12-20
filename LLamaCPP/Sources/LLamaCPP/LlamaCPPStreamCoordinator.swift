import Abstractions
import Foundation
#if DEBUG
import os.signpost
#endif

/// Coordinates the streaming generation process
internal struct LlamaCPPStreamCoordinator {
    private let model: LlamaCPPModel
    private let context: LlamaCPPContext
    private let generator: LlamaCPPGenerator
    private let shouldStop: () -> Bool

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

    private func processStream(
        input: LLMInput,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) throws {
        let deps: StreamDependencies = try prepareStreamDependencies(continuation: continuation)
        let (promptTokens, state): ([Int32], GenerationState) = try prepareForStreaming(
            input: input,
            deps: deps
        )

        // Log generation start
        Logger.generationStarted(
            promptTokens: promptTokens.count,
            maxTokens: input.limits.maxTokens
        )

        try streamTokens(
            input: input,
            promptTokenCount: promptTokens.count,
            initialState: state,
            deps: deps
        )
    }

    private func prepareForStreaming(
        input: LLMInput,
        deps: StreamDependencies
    ) throws -> ([Int32], GenerationState) {
        let promptTokens: [Int32] = try executeTokenization(input: input, deps: deps)
        let state: GenerationState = try executePromptProcessing(
            promptTokens: promptTokens,
            deps: deps,
            input: input
        )
        return (promptTokens, state)
    }

    private func executeTokenization(
        input: LLMInput,
        deps: StreamDependencies
    ) throws -> [Int32] {
        try tokenizePrompt(
            input: input,
            tokenizer: deps.tokenizer,
            modelPointer: deps.modelPointer
        )
    }

    private func executePromptProcessing(
        promptTokens: [Int32],
        deps: StreamDependencies,
        input: LLMInput
    ) throws -> GenerationState {
        try setupMetricsAndProcessPrompt(
            promptTokens: promptTokens,
            generator: deps.generator,
            input: input
        )
    }

    private func prepareStreamDependencies(
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) throws -> StreamDependencies {
        let modelPointer: OpaquePointer = try getModelPointer()
        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()
        return StreamDependencies(
            generator: generator,
            tokenizer: tokenizer,
            modelPointer: modelPointer,
            continuation: continuation
        )
    }

    private func getModelPointer() throws -> OpaquePointer {
        guard let ptr = model.pointer else {
            throw LLMError.modelNotFound("Model pointer is nil")
        }
        return ptr
    }

    private func setupMetricsAndProcessPrompt(
        promptTokens: [Int32],
        generator: LlamaCPPGenerator,
        input: LLMInput
    ) throws -> GenerationState {
        var state: GenerationState = createInitialState(
            promptTokenCount: promptTokens.count,
            input: input
        )

        try processPrompt(promptTokens: promptTokens, generator: generator, state: &state)
        configureMetrics(state: &state, input: input, promptTokens: promptTokens)

        return state
    }

    private func createInitialState(promptTokenCount: Int, input: LLMInput) -> GenerationState {
        GenerationState(
            promptTokenCount: promptTokenCount,
            collectDetailedMetrics: input.limits.collectDetailedMetrics
        )
    }

    private func processPrompt(
        promptTokens: [Int32],
        generator: LlamaCPPGenerator,
        state: inout GenerationState
    ) throws {
        state.recordPromptProcessingStart()
        let clock: ContinuousClock = ContinuousClock()
        let promptStartTime: ContinuousClock.Instant = clock.now

        #if DEBUG
        SignpostInstrumentation.signposter.emitEvent(SignpostNames.promptProcessing)
        #endif

        try generator.processBatch(tokens: promptTokens)
        state.recordPromptProcessingComplete()

        let promptDuration: Duration = promptStartTime.duration(to: clock.now)
        let attosecondsToSeconds: Double = 1e18
        let promptDurationSeconds: Double = Double(promptDuration.components.seconds) +
            Double(promptDuration.components.attoseconds) / attosecondsToSeconds
        Logger.promptProcessingCompleted(
            duration: promptDurationSeconds,
            tokenCount: promptTokens.count
        )
    }

    private func configureMetrics(
        state: inout GenerationState,
        input: LLMInput,
        promptTokens: [Int32]
    ) {
        // Record sampling parameters
        state.recordSamplingParameters(
            temperature: input.sampling.temperature,
            topP: input.sampling.topP,
            topK: input.sampling.topK.map { Int32($0) }
        )

        // Record and check context window usage
        let windowSize: Int = Int(context.contextSize)
        let tokensUsed: Int = promptTokens.count
        state.recordContextInfo(windowSize: windowSize, tokensUsed: tokensUsed)

        checkContextUsage(tokensUsed: tokensUsed, windowSize: windowSize)
    }

    private func checkContextUsage(tokensUsed: Int, windowSize: Int) {
        let usagePercent: Double = Double(tokensUsed) / Double(windowSize)
        let contextWarningThreshold: Double = 0.8
        if usagePercent > contextWarningThreshold {
            Logger.contextWindowWarning(used: tokensUsed, total: windowSize)
        }
    }

    private func tokenizePrompt(
        input: LLMInput,
        tokenizer: LlamaCPPTokenizer,
        modelPointer: OpaquePointer
    ) throws -> [Int32] {
        #if DEBUG
        SignpostInstrumentation.signposter.emitEvent(SignpostNames.promptTokenization)
        #endif
        return try tokenizer.tokenize(
            text: input.context,
            addBos: true,
            modelPointer: modelPointer
        )
    }

    private func streamTokens(
        input: LLMInput,
        promptTokenCount _: Int,
        initialState: GenerationState,
        deps: StreamDependencies
    ) throws {
        var context: StreamContext = createStreamContext(
            input: input,
            initialState: initialState,
            deps: deps
        )
        try processTokenLoop(input: input, deps: deps, context: &context)
        finishStream(context: context, deps: deps)
    }

    @inline(__always)
    private func createStreamContext(
        input: LLMInput,
        initialState: GenerationState,
        deps: StreamDependencies
    ) -> StreamContext {
        StreamContext(
            state: initialState,
            maxTokens: input.limits.maxTokens,
            eosToken: deps.tokenizer.eosToken(modelPointer: deps.modelPointer),
            stopSequences: input.sampling.stopSequences,
            buffer: ""
        )
    }

    @inline(__always)
    private func processTokenLoop(
        input: LLMInput,
        deps: StreamDependencies,
        context: inout StreamContext
    ) throws {
        while context.state.generatedTokenCount < context.maxTokens, !shouldStop() {
            let shouldBreak: Bool = try LlamaCPPStreamHandler.processNextToken(
                deps: deps,
                input: input,
                context: &context
            )
            if shouldBreak {
                break
            }
        }
    }

    private func finishStream(context: StreamContext, deps: StreamDependencies) {
        LlamaCPPStreamHandler.sendFinishedEvent(
            context: context,
            continuation: deps.continuation,
            shouldStop: shouldStop()
        )
        deps.continuation.finish()
    }

    // Type aliases for cleaner code
    internal typealias StreamContext = LlamaCPPStreamHandler.Context
    internal typealias StreamDependencies = LlamaCPPStreamHandler.Dependencies
}
