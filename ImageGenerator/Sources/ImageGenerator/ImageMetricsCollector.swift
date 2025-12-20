import Abstractions
import Foundation
import OSLog

/// Thread-safe metrics collector for image generation.
///
/// This actor collects timing and usage metrics during the Stable Diffusion
/// image generation process, providing a unified interface for metrics collection.
actor ImageMetricsCollector {
    // MARK: - Properties

    /// Logger for metrics collection events
    private static let logger = Logger(
        subsystem: "ImageGenerator",
        category: "ImageMetricsCollector"
    )

    /// Monotonic clock for accurate timing
    private let clock = ContinuousClock()

    /// Generation start time
    private let startInstant: ContinuousClock.Instant

    /// Model loading start time
    private var modelLoadStartInstant: ContinuousClock.Instant?

    /// Model loading end time
    private var modelLoadEndInstant: ContinuousClock.Instant?

    /// Prompt encoding start time
    private var promptEncodingStartInstant: ContinuousClock.Instant?

    /// Prompt encoding end time
    private var promptEncodingEndInstant: ContinuousClock.Instant?

    /// Denoising start time
    private var denoisingStartInstant: ContinuousClock.Instant?

    /// VAE decoding start time
    private var vaeDecodingStartInstant: ContinuousClock.Instant?

    /// VAE decoding end time
    private var vaeDecodingEndInstant: ContinuousClock.Instant?

    /// Post-processing start time
    private var postProcessingStartInstant: ContinuousClock.Instant?

    /// Post-processing end time
    private var postProcessingEndInstant: ContinuousClock.Instant?

    /// Individual step timings
    private var denoisingStepTimings: [Duration] = []

    /// Memory snapshots
    private var activeMemory: UInt64 = 0
    private var peakMemory: UInt64 = 0

    /// Model information
    private var modelName: String?
    private var modelParameters: Int = 0

    /// Generation parameters
    private var width: Int?
    private var height: Int?
    private var steps: Int?
    private var guidanceScale: Float?
    private var scheduler: String?
    private var seed: UInt32?
    private var batchSize: Int = 1

    /// Token counts
    private var promptTokens: Int?
    private var negativePromptTokens: Int?

    /// GPU usage
    private var usedGPU: Bool = false
    private var gpuMemory: UInt64?

    // MARK: - Initialization

    /// Initialize a new metrics collector.
    init() {
        self.startInstant = clock.now
        Self.logger.debug("ImageMetricsCollector initialized")
    }

    // MARK: - Timing Methods

    /// Mark the start of model loading.
    func startModelLoading() {
        modelLoadStartInstant = clock.now
        Self.logger.info("Model loading started")
    }

    /// Mark the end of model loading.
    func endModelLoading() {
        modelLoadEndInstant = clock.now
        if let startTime = modelLoadStartInstant {
            let duration = startTime.duration(to: clock.now)
            Self.logger.notice("Model loading completed in \(duration)")
        }
    }

    /// Mark the start of prompt encoding.
    func startPromptEncoding() {
        promptEncodingStartInstant = clock.now
        Self.logger.debug("Prompt encoding started")
    }

    /// Mark the end of prompt encoding.
    func endPromptEncoding() {
        promptEncodingEndInstant = clock.now
        if let startTime = promptEncodingStartInstant {
            let duration = startTime.duration(to: clock.now)
            Self.logger.debug("Prompt encoding completed in \(duration)")
        }
    }

    /// Mark the start of denoising.
    func startDenoising() {
        denoisingStartInstant = clock.now
        Self.logger.info("Denoising process started")
    }

    /// Record timing for a denoising step.
    func recordDenoisingStep() {
        guard let start = denoisingStartInstant else { return }
        let stepDuration = start.duration(to: clock.now)
        denoisingStepTimings.append(stepDuration)
    }

    /// Mark the start of VAE decoding.
    func startVAEDecoding() {
        vaeDecodingStartInstant = clock.now
        Self.logger.debug("VAE decoding started")
    }

    /// Mark the end of VAE decoding.
    func endVAEDecoding() {
        vaeDecodingEndInstant = clock.now
        if let startTime = vaeDecodingStartInstant {
            let duration = startTime.duration(to: clock.now)
            Self.logger.debug("VAE decoding completed in \(duration)")
        }
    }

    /// Mark the start of post-processing.
    func startPostProcessing() {
        postProcessingStartInstant = clock.now
    }

    /// Mark the end of post-processing.
    func endPostProcessing() {
        postProcessingEndInstant = clock.now
    }

    // MARK: - Memory Methods

    /// Update memory usage information.
    func updateMemoryUsage(active: UInt64, peak: UInt64) {
        self.activeMemory = active
        self.peakMemory = max(self.peakMemory, peak)
    }

    /// Update GPU memory usage.
    func updateGPUMemory(_ bytes: UInt64) {
        self.gpuMemory = bytes
        self.usedGPU = true
    }

    // MARK: - Model Information

    /// Set model information.
    func setModelInfo(name: String, parameters: Int) {
        self.modelName = name
        self.modelParameters = parameters
    }

    // MARK: - Generation Parameters

    /// Set generation configuration.
    func setGenerationConfig(
        width: Int,
        height: Int,
        steps: Int,
        guidanceScale: Float,
        scheduler: String,
        seed: UInt32? = nil,
        batchSize: Int = 1
    ) {
        self.width = width
        self.height = height
        self.steps = steps
        self.guidanceScale = guidanceScale
        self.scheduler = scheduler
        self.seed = seed
        self.batchSize = batchSize
    }

    /// Set token counts.
    func setTokenCounts(prompt: Int?, negativePrompt: Int? = nil) {
        self.promptTokens = prompt
        self.negativePromptTokens = negativePrompt
        Self.logger.debug("Token counts - prompt: \(prompt ?? 0), negative: \(negativePrompt ?? 0)")
    }

    // MARK: - Metrics Creation

    /// Create ImageMetrics from collected data.
    func createMetrics() -> ImageMetrics {
        let timing = createTimingMetrics()
        let usage = createUsageMetrics()
        let generation = createGenerationMetrics()

        let totalTime = startInstant.duration(to: clock.now)
        Self.logger.notice("Metrics created - total time: \(totalTime), steps: \(self.steps ?? 0)")

        return ImageMetrics(
            timing: timing,
            usage: usage,
            generation: generation
        )
    }

    // MARK: - Private Metrics Creation

    /// Create timing metrics from collected data.
    private func createTimingMetrics() -> ImageTimingMetrics {
        let endInstant = clock.now
        let totalTime = startInstant.duration(to: endInstant)

        return ImageTimingMetrics(
            totalTime: totalTime,
            modelLoadTime: calculateDuration(
                from: modelLoadStartInstant,
                to: modelLoadEndInstant
            ),
            promptEncodingTime: calculateDuration(
                from: promptEncodingStartInstant,
                to: promptEncodingEndInstant
            ),
            denoisingStepTimes: denoisingStepTimings,
            vaeDecodingTime: calculateDuration(
                from: vaeDecodingStartInstant,
                to: vaeDecodingEndInstant
            ),
            postProcessingTime: calculateDuration(
                from: postProcessingStartInstant,
                to: postProcessingEndInstant
            )
        )
    }

    /// Create usage metrics from collected data.
    private func createUsageMetrics() -> ImageUsageMetrics {
        return ImageUsageMetrics(
            activeMemory: activeMemory,
            peakMemory: peakMemory,
            modelParameters: modelParameters,
            promptTokens: promptTokens,
            negativePromptTokens: negativePromptTokens,
            gpuMemory: gpuMemory,
            usedGPU: usedGPU
        )
    }

    // MARK: - Private Methods

    /// Calculate duration between two optional instants.
    private func calculateDuration(
        from start: ContinuousClock.Instant?,
        to end: ContinuousClock.Instant?
    ) -> Duration? {
        guard let start = start, let end = end else { return nil }
        return start.duration(to: end)
    }

    /// Create generation metrics if all required data is available.
    private func createGenerationMetrics() -> ImageGenerationMetrics? {
        guard let width = width,
              let height = height,
              let steps = steps,
              let guidanceScale = guidanceScale,
              let scheduler = scheduler,
              let modelName = modelName else {
            return nil
        }

        return ImageGenerationMetrics(
            width: width,
            height: height,
            steps: steps,
            guidanceScale: guidanceScale,
            scheduler: scheduler,
            modelName: modelName,
            seed: seed,
            safetyCheckPassed: true,
            batchSize: batchSize
        )
    }
}
