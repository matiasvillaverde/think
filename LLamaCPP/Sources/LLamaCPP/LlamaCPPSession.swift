import Abstractions
import Foundation

#if DEBUG
    import os.signpost
#endif

/// LlamaCPP implementation of the LLMSession protocol
internal actor LlamaCPPSession: LLMSession {
    private var configuration: ProviderConfiguration?
    private var model: LlamaCPPModel?
    private var context: LlamaCPPContext?
    private var generator: LlamaCPPGenerator?
    private var isGenerating: Bool = false
    private let stopFlag: StopFlag = StopFlag()

    /// Stream text generation based on the provided configuration
    internal func stream(_ input: LLMInput) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let generationTask: Task<Void, Never> = createGenerationTask(
                input: input,
                continuation: continuation
            )
            let timeoutTask: Task<Void, Never>? = setupTimeoutIfNeeded(
                input: input,
                generationTask: generationTask,
                continuation: continuation
            )

            continuation.onTermination = { _ in
                timeoutTask?.cancel()
                generationTask.cancel()
                self.triggerStop()
            }
        }
    }

    private func createGenerationTask(
        input: LLMInput,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) -> Task<Void, Never> {
        Task {
            // Reset stop flag
            stopFlag.reset()
            isGenerating = true
            defer {
                isGenerating = false
            }

            do {
                // Load model if not loaded
                if model == nil {
                    try loadModel()
                }

                // Start generation
                try generateStream(input: input, continuation: continuation)
            } catch is CancellationError {
                // Don't finish with error for cancellation - it's already handled by timeout
                Logger.generationCancelled(reason: "Task cancelled")
                return
            } catch {
                Logger.generationFailed(error: error)
                continuation.finish(throwing: error)
            }
        }
    }

    private func setupTimeoutIfNeeded(
        input: LLMInput,
        generationTask: Task<Void, Never>,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) -> Task<Void, Never>? {
        guard let maxTime = input.limits.maxTime else {
            return nil
        }

        return createTimeoutTask(
            maxTime: maxTime,
            generationTask: generationTask,
            continuation: continuation
        )
    }

    private func createTimeoutTask(
        maxTime: Duration,
        generationTask: Task<Void, Never>,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) -> Task<Void, Never> {
        Task {
            do {
                try await Task.sleep(for: maxTime)
            } catch {
                return  // Cancelled - generation completed normally
            }
            self.triggerStop()
            if !generationTask.isCancelled {
                generationTask.cancel()
                Logger.generationCancelled(reason: "Timeout exceeded")
                continuation.finish(
                    throwing: LLMError.providerError(
                        code: "TIMEOUT",
                        message: "Generation exceeded maximum time limit"
                    )
                )
            }
        }
    }

    /// Stop the current generation
    nonisolated internal func stop() {
        stopFlag.set(true)
        Logger.generationCancelled(reason: "User requested stop")
    }

    /// Internal method to trigger stop from timeout
    nonisolated private func triggerStop() {
        stopFlag.set(true)
    }
    /// Preload a model into memory with progress reporting
    internal func preload(configuration: ProviderConfiguration) -> AsyncThrowingStream<
        Progress, Error
    > {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Store the configuration
                    self.configuration = configuration
                    if model != nil {
                        sendAlreadyLoadedProgress(to: continuation)
                        return
                    }
                    try sendLoadingProgress(to: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func sendAlreadyLoadedProgress(
        to continuation: AsyncThrowingStream<Progress, Error>.Continuation
    ) {
        let singleStep: Int64 = 1
        let progress: Progress = Progress(totalUnitCount: singleStep)
        progress.completedUnitCount = singleStep
        progress.localizedDescription = "Model already loaded"
        continuation.yield(progress)
        continuation.finish()
    }

    private func sendLoadingProgress(
        to continuation: AsyncThrowingStream<Progress, Error>.Continuation
    ) throws {
        let totalSteps: Int64 = 2
        let (initialStep, finalStep): (Int64, Int64) = (0, 2)

        // Report initial progress
        var progress: Progress = Progress(totalUnitCount: totalSteps)
        progress.localizedDescription = "Loading model"
        progress.localizedAdditionalDescription = "Initializing..."
        progress.completedUnitCount = initialStep
        continuation.yield(progress)

        try loadModel() // Load the model

        // Report completion
        progress = Progress(totalUnitCount: totalSteps)
        progress.localizedDescription = "Loading model"
        progress.localizedAdditionalDescription = "Model loaded successfully"
        progress.completedUnitCount = finalStep
        continuation.yield(progress)
        continuation.finish()
    }

    private func setupComponents(model loadedModel: LlamaCPPModel, context loadedContext: LlamaCPPContext) {
        model = loadedModel; context = loadedContext
        generator = LlamaCPPGenerator(model: loadedModel, context: loadedContext)
    }

    private func loadModelFromPath() throws -> LlamaCPPModel {
        guard let configuration else {
            throw LLMError.invalidConfiguration("Configuration not set. Call preload first.")
        }
        return try LlamaCPPModel(
            path: configuration.location.path,
            configuration: getExtendedConfig(configuration.compute)
        )
    }

    private func performContextCreation(model loadedModel: LlamaCPPModel) throws -> LlamaCPPContext {
        guard let configuration else {
            throw LLMError.invalidConfiguration("Configuration not set. Call preload first.")
        }
        do {
            let context: LlamaCPPContext = try LlamaCPPContext(
                model: loadedModel,
                configuration: configuration.compute
            )
            Logger.contextCreated(
                contextSize: Int32(configuration.compute.contextSize),
                batchSize: Int32(configuration.compute.batchSize)
            )
            return context
        } catch {
            Logger.contextCreationFailed(error: error)
            throw error
        }
    }

    /// Unload a model from memory
    internal func unload() {
        generator?.free(); generator = nil
        context?.free(); context = nil
        model?.free(); model = nil
        Logger.modelUnloaded()
    }

    // MARK: - Private Methods
    private func loadModel() throws {
        #if DEBUG
            let signpostID: OSSignpostID = SignpostInstrumentation.signposter.makeSignpostID()
            let modelLoadState: OSSignpostIntervalState = SignpostInstrumentation.signposter
                .beginInterval(
                    SignpostNames.modelLoad,
                    id: signpostID
                )
            defer {
                SignpostInstrumentation.signposter.endInterval(
                    SignpostNames.modelLoad,
                    modelLoadState
                )
            }
        #endif

        try performModelLoad()
    }

    private func performModelLoad() throws {
        guard let configuration else {
            throw LLMError.invalidConfiguration("Configuration not set. Call preload first.")
        }
        let clock: ContinuousClock = ContinuousClock()
        let startTime: ContinuousClock.Instant = clock.now
        Logger.modelLoadStarted(path: configuration.location.path)
        do {
            let loadedModel: LlamaCPPModel = try loadModelFromPath()
            let loadedContext: LlamaCPPContext = try createContext(model: loadedModel)
            setupComponents(model: loadedModel, context: loadedContext)

            let duration: Duration = startTime.duration(to: clock.now)
            let attosecondsToSeconds: Double = 1e18
            let durationSeconds: Double =
                Double(duration.components.seconds) + Double(duration.components.attoseconds)
                / attosecondsToSeconds
            Logger.modelLoadCompleted(duration: durationSeconds)
        } catch {
            Logger.modelLoadFailed(error: error)
            throw error
        }
    }

    private func createContext(model loadedModel: LlamaCPPModel) throws -> LlamaCPPContext {
        #if DEBUG
            let signpostID: OSSignpostID = SignpostInstrumentation.signposter.makeSignpostID()
            let contextCreateState: OSSignpostIntervalState = SignpostInstrumentation.signposter
                .beginInterval(
                    SignpostNames.contextCreate,
                    id: signpostID
                )
            defer {
                SignpostInstrumentation.signposter.endInterval(
                    SignpostNames.contextCreate,
                    contextCreateState
                )
            }
        #endif

        return try performContextCreation(model: loadedModel)
    }

    private func generateStream(
        input: LLMInput,
        continuation: AsyncThrowingStream<LLMStreamChunk, Error>.Continuation
    ) throws {
        guard let model = self.model,
            let context = self.context,
            let generator = self.generator
        else {
            throw LLMError.modelNotFound("Model not loaded")
        }

        let coordinator: LlamaCPPStreamCoordinator = LlamaCPPStreamCoordinator(
            model: model,
            context: context,
            generator: generator
        ) { [stopFlag] in stopFlag.get() }

        try coordinator.executeStream(input: input, continuation: continuation)
    }
}

// MARK: - Configuration Helpers

private func getExtendedConfig(_ config: ComputeConfiguration) -> ComputeConfigurationExtended {
    ComputeConfigurationExtended(from: config, gpuEnabled: true)
}
