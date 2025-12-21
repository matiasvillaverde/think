import Abstractions
import CoreImage
import Foundation
import MLX
import OSLog

// swiftlint:disable type_body_length
/// MLX implementation of the LLMSession protocol
internal actor MLXSession: LLMSession {
    // MARK: - Properties

    private let logger = Logger(subsystem: "MLXSession", category: "MLXSession")

    #if DEBUG
    private let debugLogger = Logger(
        subsystem: "MLXSession",
        category: "MLXSession.Debug"
    )
    #endif

    private var configuration: ProviderConfiguration?
    private var modelContainer: ModelContainer?
    private var isGenerating = false
    private let stopFlag = StopFlag()
    private let clock = ContinuousClock() // Metrics tracking

    /// Stream text generation based on the provided configuration
    internal func stream(_ input: LLMInput) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    stopFlag.reset()
                    isGenerating = true
                    defer { isGenerating = false }

                    logger.debug("Starting stream generation")

                    if modelContainer == nil {
                        logger.info("Model not preloaded - loading on demand")
                        try await loadModel()
                    }

                    try await generateStream(input: input, continuation: continuation)
                    continuation.finish()
                } catch {
                    logger.error("Stream generation failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Stop the current generation
    nonisolated internal func stop() {
        logger.info("Stop requested - setting stop flag")
        stopFlag.set(true)
    }

    /// Preload a model into memory with progress streaming
    internal func preload(configuration: ProviderConfiguration) -> AsyncThrowingStream<Progress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                self.configuration = configuration
                if modelContainer != nil {
                    let progress = Progress(totalUnitCount: 100)
                    progress.completedUnitCount = 100
                    continuation.yield(progress)
                    continuation.finish()
                    return
                }
                do {
                    try await streamModelLoad(continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Unload a model from memory
    internal func unload() {
        if modelContainer != nil {
            logger.info("Unloading model from memory")
            modelContainer = nil
        } else {
            logger.debug("Unload called but no model was loaded")
        }
    }
    // MARK: - Private Methods

    private func streamModelLoad(
        continuation: AsyncThrowingStream<Progress, Error>.Continuation
    ) async throws {
        guard let configuration else {
            logger.error("Cannot preload model: Configuration not set")
            throw LLMError.invalidConfiguration("Configuration not set. Call preload first.")
        }

        let loadStart = clock.now
        logger.info("Preloading model from \(configuration.location.path)")

        let progress = Progress(totalUnitCount: 100)
        progress.localizedDescription = "Loading MLX model"
        continuation.yield(progress)

        modelContainer = try await loadModelContainer(
            directory: configuration.location
        ) { continuation.yield($0) }

        let duration = loadStart.duration(to: clock.now)
        logger.info("Model preloaded in \(duration)")
        if duration > .seconds(30) {
            logger.warning("Slow preload: \(duration)")
        }
    }

    private func loadModel() async throws {
        guard let configuration else {
            logger.error("Model not loaded: Configuration must be set via preload() before generation")
            throw LLMError.invalidConfiguration("Configuration not set. Call preload first.")
        }

        let loadStart = clock.now
        logger.info("Loading model from \(configuration.location.path)")

        modelContainer = try await loadModelContainer(
            directory: configuration.location
        ) { _ in /* Progress callback not used */ }

        let duration = loadStart.duration(to: clock.now)
        logger.info("Model loaded in \(duration)")
        if duration > .seconds(10) {
            logger.warning("Slow load: \(duration)")
        }
    }

    private func generateStream(
        input: LLMInput,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) async throws {
        guard let container = modelContainer else {
            logger.error("Model not loaded: Configuration must be set via preload() before generation")
            throw LLMError.modelNotFound("Model not loaded")
        }
        if !input.images.isEmpty || !input.videoURLs.isEmpty {
            let supportsVision = await container.perform { context in
                context.model is VLMModel
            }
            if !supportsVision {
                logger.error("Invalid input: model does not support image/video inputs")
                throw LLMError.invalidConfiguration("Model does not support image/video inputs")
            }
        }
        try await performGeneration(container: container, input: input, continuation: continuation)
    }

    private func performGeneration(
        container: ModelContainer,
        input: LLMInput,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) async throws {
        let generateParams = createGenerateParameters(from: input.sampling)
        let generationStartTime = clock.now

        #if DEBUG
        debugLogger.info(
            "Starting generation: \(input.limits.maxTokens) tokens, temp \(generateParams.temperature)"
        )
        #endif

        let metricsData = try await generateTokens(
            container: container,
            input: input,
            parameters: generateParams,
            generationStartTime: generationStartTime,
            continuation: continuation
        )

        let metrics = buildMetrics(from: metricsData)
        continuation.yield(LLMStreamChunk(text: "", event: .finished, metrics: metrics))

        logGenerationMetrics(metricsData: metricsData, startTime: generationStartTime)
    }

    private func logGenerationMetrics(metricsData: MetricsData, startTime: ContinuousClock.Instant) {
        let totalDuration = startTime.duration(to: clock.now)
        let durationSeconds = Double(totalDuration.components.seconds) +
            Double(totalDuration.components.attoseconds) / 1e18
        let tokensPerSecond = Double(metricsData.generatedTokenCount) / durationSeconds
        let tokPerSec = String(format: "%.2f", tokensPerSecond)

        #if DEBUG
        let totalTokens = metricsData.promptTokenCount + metricsData.generatedTokenCount
        debugLogger.info("""
            Generation complete: \(metricsData.generatedTokenCount)/\(totalTokens) tokens, \
            \(totalDuration), \(tokPerSec) tok/s
            """)
        #endif

        logger.info(
            "Generation: \(metricsData.generatedTokenCount) tokens, \(totalDuration), \(tokPerSec) tok/s"
        )

        // Performance warnings
        if tokensPerSecond < 1.0 {
            logger.warning("Very slow generation: \(tokPerSec) tok/s")
        } else if tokensPerSecond < 5.0 {
            logger.warning("Slow generation: \(tokPerSec) tok/s")
        }
    }

    private func generateTokens(
        container: ModelContainer,
        input: LLMInput,
        parameters: GenerateParameters,
        generationStartTime: ContinuousClock.Instant,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) async throws -> MetricsData {
        try await container.perform { [clock] context in
            let genContext = GenerationContext(
                modelContext: context,
                input: input,
                parameters: parameters,
                generationStartTime: generationStartTime,
                continuation: continuation,
                clock: clock
            )
            return try await self.executeGeneration(genContext)
        }
    }

    // swiftlint:disable:next function_body_length
    nonisolated private func executeGeneration(
        _ genContext: GenerationContext
    ) async throws -> MetricsData {
        let promptStartTime = genContext.clock.now

        let mlxInput: LMInput
        if genContext.input.images.isEmpty,
            genContext.input.videoURLs.isEmpty {
            mlxInput = try genContext.modelContext.tokenize(prompt: genContext.input.context)
        } else {
            let images = genContext.input.images.map { UserInput.Image.ciImage(CIImage(cgImage: $0)) }
            let videos = genContext.input.videoURLs.map { UserInput.Video.url($0) }
            let userInput = UserInput(prompt: genContext.input.context, images: images, videos: videos)
            mlxInput = try await genContext.modelContext.prepare(input: userInput)
        }

        let promptEndTime = genContext.clock.now
        let tokenizeDuration = promptStartTime.duration(to: promptEndTime)

        #if DEBUG
        debugLogger.info("Tokenization complete: \(mlxInput.text.tokens.count) tokens, \(tokenizeDuration)")
        #endif

        if tokenizeDuration > .seconds(10) {
            logger.warning("Slow tokenization: \(tokenizeDuration) for \(mlxInput.text.tokens.count) tokens")
        }

        let state = GenerationState()
        let tokenContext = TokenContext(
            state: state,
            context: genContext.modelContext,
            input: genContext.input,
            continuation: genContext.continuation,
            clock: genContext.clock
        )

        _ = try generate(
            input: mlxInput,
            parameters: genContext.parameters,
            context: genContext.modelContext
        ) { [stopFlag] tokens in
            // Check if we should stop generation
            if stopFlag.get() {
                return .stop
            }
            return processToken(tokens: tokens, tokenContext: tokenContext)
        }

        return MetricsData(
            generationStartTime: genContext.generationStartTime,
            promptStartTime: promptStartTime,
            promptEndTime: promptEndTime,
            firstTokenTime: state.firstTokenTime,
            promptTokenCount: mlxInput.text.tokens.count,
            generatedTokenCount: state.generatedTokenCount,
            stopReason: state.stopReason,
            parameters: genContext.parameters
        )
    }

    // swiftlint:disable:next function_body_length
    nonisolated private func processToken(
        tokens: [Int],
        tokenContext: TokenContext
    ) -> GenerateDisposition {
        // Track first token time
        if tokenContext.state.firstTokenTime == nil {
            tokenContext.state.firstTokenTime = tokenContext.clock.now
            #if DEBUG
            debugLogger.info("First token received")
            #endif
        }

        // Decode only the new tokens (not all tokens!)
        let newTokens = Array(tokens.suffix(tokens.count - tokenContext.state.allTokens.count))
        let text = tokenContext.context.tokenizer.decode(tokens: newTokens)

        #if DEBUG
        debugLogger.debug("""
            Token #\(tokens.count): '\(text, privacy: .public)' \
            [IDs: \(newTokens.map { String($0) }.joined(separator: ","), privacy: .public)]
            """)
        debugLogger.debug("   Total text: '\(tokenContext.state.generatedText + text, privacy: .public)'")
        #endif

        // Update state efficiently
        tokenContext.state.allTokens = tokens
        tokenContext.state.generatedTokenCount = tokens.count
        tokenContext.state.generatedText += text  // Accumulate text incrementally

        // Yield chunk
        tokenContext.continuation.yield(LLMStreamChunk(text: text, event: .text))

        // Check stop conditions
        if tokens.count >= tokenContext.input.limits.maxTokens {
            tokenContext.state.stopReason = .maxTokens
            #if DEBUG
            let limit = tokenContext.input.limits.maxTokens
            debugLogger.warning("Stopping: Max tokens reached (\(tokens.count)/\(limit))")
            #endif
            return .stop
        }

        // Check stop sequences on accumulated text (avoiding full re-decode)
        for stopSeq in tokenContext.input.sampling.stopSequences
            where tokenContext.state.generatedText.contains(stopSeq) {
            tokenContext.state.stopReason = .stopSequence
            #if DEBUG
            debugLogger.warning("Stopping: Stop sequence '\(stopSeq, privacy: .public)' detected")
            #endif
            return .stop
        }

        #if DEBUG
        // Check for potential issues with thinking tags
        if tokenContext.state.generatedText == "<think>" {
            debugLogger.warning("Only generated <think> tag - model may be stuck")
        }
        #endif

        return .more
    }

    private func createGenerateParameters(from sampling: SamplingParameters) -> GenerateParameters {
        GenerateParameters(
            temperature: sampling.temperature,
            topP: sampling.topP,
            repetitionPenalty: sampling.repetitionPenalty ?? 1.0,
            repetitionContextSize: sampling.repetitionPenaltyRange ?? 64,
            prefillStepSize: 512
        )
    }

    // MARK: - Metrics Helpers

    private func buildMetrics(from data: MetricsData) -> ChunkMetrics {
        let totalDuration = data.generationStartTime.duration(to: clock.now)
        let promptProcessingTime = data.promptStartTime.duration(to: data.promptEndTime)
        let timeToFirstToken = data.firstTokenTime.map { data.generationStartTime.duration(to: $0) }

        return ChunkMetrics(
            timing: TimingMetrics(
                totalTime: totalDuration,
                timeToFirstToken: timeToFirstToken,
                timeSinceLastToken: nil,
                tokenTimings: [],
                promptProcessingTime: promptProcessingTime
            ),
            usage: UsageMetrics(
                generatedTokens: data.generatedTokenCount,
                totalTokens: data.promptTokenCount + data.generatedTokenCount,
                promptTokens: data.promptTokenCount,
                contextWindowSize: configuration?.compute.contextSize,
                contextTokensUsed: data.promptTokenCount + data.generatedTokenCount
            ),
            generation: GenerationMetrics(
                stopReason: data.stopReason,
                temperature: data.parameters.temperature,
                topP: data.parameters.topP
            )
        )
    }
}
// swiftlint:enable type_body_length
