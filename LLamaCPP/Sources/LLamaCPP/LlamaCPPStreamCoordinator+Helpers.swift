import Abstractions
import Foundation

extension LlamaCPPStreamCoordinator {
    internal func processStream(
        input: LLMInput,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) throws {
        let deps: StreamDependencies = try prepareStreamDependencies(continuation: continuation)
        let prepared: PreparedStream = try prepareForStreaming(
            input: input,
            deps: deps
        )

        // Log generation start
        Logger.generationStarted(
            promptTokens: prepared.promptTokens.count,
            maxTokens: prepared.maxTokens
        )

        try streamTokens(
            input: input,
            maxTokens: prepared.maxTokens,
            initialState: prepared.state,
            deps: deps
        )
    }

    private func prepareForStreaming(
        input: LLMInput,
        deps: StreamDependencies
    ) throws -> PreparedStream {
        let rawPromptTokens: [Int32] = try executeTokenization(input: input, deps: deps)
        let adjusted: (promptTokens: [Int32], maxTokens: Int) = adjustPromptTokensForContext(
            promptTokens: rawPromptTokens,
            maxTokens: input.limits.maxTokens
        )
        let state: GenerationState = try executePromptProcessing(
            promptTokens: adjusted.promptTokens,
            deps: deps,
            input: input
        )
        return PreparedStream(
            promptTokens: adjusted.promptTokens,
            state: state,
            maxTokens: adjusted.maxTokens
        )
    }

    private func adjustPromptTokensForContext(
        promptTokens: [Int32],
        maxTokens: Int
    ) -> (promptTokens: [Int32], maxTokens: Int) {
        guard let contextSize = resolvedContextSize() else {
            return ([], 0)
        }

        let requestedMaxTokens: Int = max(0, maxTokens)
        let promptBudget: Int = calculatePromptBudget(
            contextSize: contextSize,
            requestedMaxTokens: requestedMaxTokens
        )
        let adjustedPromptTokens: [Int32] = truncatePromptTokensIfNeeded(
            promptTokens,
            budget: promptBudget,
            contextSize: contextSize,
            requestedMaxTokens: requestedMaxTokens
        )
        let effectiveMaxTokens: Int = clampMaxTokens(
            requestedMaxTokens: requestedMaxTokens,
            contextSize: contextSize,
            promptCount: adjustedPromptTokens.count
        )

        return (adjustedPromptTokens, effectiveMaxTokens)
    }

    private func resolvedContextSize() -> Int? {
        let contextSize: Int = max(0, Int(context.contextSize))
        guard contextSize > 0 else {
            Logger.invalidConfiguration(message: "Context size is zero")
            return nil
        }
        return contextSize
    }

    private func calculatePromptBudget(
        contextSize: Int,
        requestedMaxTokens: Int
    ) -> Int {
        let maxTokensBudget: Int = min(requestedMaxTokens, max(0, contextSize - 1))
        return max(0, contextSize - maxTokensBudget)
    }

    private func truncatePromptTokensIfNeeded(
        _ promptTokens: [Int32],
        budget: Int,
        contextSize: Int,
        requestedMaxTokens: Int
    ) -> [Int32] {
        guard promptTokens.count > budget else {
            return promptTokens
        }

        let adjustedPromptTokens: [Int32]
        if budget == 0 {
            adjustedPromptTokens = []
        } else {
            adjustedPromptTokens = Array(promptTokens.suffix(budget))
        }

        Logger.promptTruncated(
            original: promptTokens.count,
            trimmed: adjustedPromptTokens.count,
            contextSize: contextSize,
            requestedMaxTokens: requestedMaxTokens
        )

        return adjustedPromptTokens
    }

    private func clampMaxTokens(
        requestedMaxTokens: Int,
        contextSize: Int,
        promptCount: Int
    ) -> Int {
        let effectiveMaxTokens: Int = min(
            requestedMaxTokens,
            max(0, contextSize - promptCount)
        )
        if effectiveMaxTokens != requestedMaxTokens {
            Logger.maxTokensClamped(
                requested: requestedMaxTokens,
                effective: effectiveMaxTokens,
                contextSize: contextSize
            )
        }
        return effectiveMaxTokens
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
        maxTokens: Int,
        initialState: GenerationState,
        deps: StreamDependencies
    ) throws {
        var context: StreamContext = createStreamContext(
            input: input,
            maxTokens: maxTokens,
            initialState: initialState,
            deps: deps
        )
        try processTokenLoop(input: input, deps: deps, context: &context)
        finishStream(context: context, deps: deps)
    }

    @inline(__always)
    private func createStreamContext(
        input: LLMInput,
        maxTokens: Int,
        initialState: GenerationState,
        deps: StreamDependencies
    ) -> StreamContext {
        StreamContext(
            state: initialState,
            maxTokens: maxTokens,
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

    internal typealias StreamContext = LlamaCPPStreamHandler.Context
    internal typealias StreamDependencies = LlamaCPPStreamHandler.Dependencies
}
