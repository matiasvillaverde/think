import Abstractions
import CoreGraphics
import CoreML
import Foundation
import os.log

extension ImageGenerator {
    // MARK: - Private Methods

    internal func performLoad(
        model: SendableModel,
        continuation: AsyncThrowingStream<
            ImageGenerationProgress, Error
        >.Continuation
    ) async throws {
        logger.info("Loading model: \(model.id)")
        let loadStartTime = ContinuousClock.now

        // Report initial progress
        continuation.yield(.init(stage: .loadingTokenizer))

        // Load and configure pipeline
        let pipeline = try await loadPipeline(for: model, continuation: continuation)
        pipelines[model.id] = pipeline

        // Initialize metrics
        initializeMetrics(for: model, loadStartTime: loadStartTime)

        // Complete loading
        continuation.yield(.init(stage: .completed))
        continuation.finish()

        let loadDuration = loadStartTime.duration(to: ContinuousClock.now)
        logger.info("Model loaded successfully in \(loadDuration)")
    }

    private func loadPipeline(
        for model: SendableModel,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) async throws -> any StableDiffusionPipelineProtocol {
        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = .cpuAndGPU

        guard let modelURL = await modelDownloader.getModelLocation(for: model.location) else {
            throw ImageGeneratorError.modelNotFound(modelName: model.id.uuidString)
        }

        let isXL = try isXLModel(at: modelURL)
        return try createPipeline(
            isXL: isXL,
            modelURL: modelURL,
            configuration: mlConfig,
            continuation: continuation
        )
    }

    private func initializeMetrics(for model: SendableModel, loadStartTime: ContinuousClock.Instant) {
        let collector = ImageMetricsCollector()
        metricsCollectors[model.id] = collector

        Task {
            await collector.startModelLoading()
            await collector.endModelLoading()
            await collector.setModelInfo(
                name: model.location,
                parameters: Int(model.metadata?.parameters.count ?? 0)
            )
        }
    }

    internal func performGenerate(
        model: SendableModel,
        config: ImageConfiguration,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) async throws {
        guard let pipeline = pipelines[model.id] else {
            throw ImageGeneratorError.modelNotLoaded
        }

        // Get or create metrics collector for this model
        let collector = metricsCollectors[model.id] ?? ImageMetricsCollector()
        if metricsCollectors[model.id] == nil {
            metricsCollectors[model.id] = collector
            // Set model info for newly created collector
            await collector.setModelInfo(
                name: model.location,
                parameters: Int(model.metadata?.parameters.count ?? 0)
            )
        }

        logger.info("Starting image generation with prompt: '\(config.prompt)'")

        let pipelineConfig = createPipelineConfiguration(
            from: config,
            pipeline: pipeline
        )

        logger.info("Generating with seed: \(pipelineConfig.seed)")

        try await generateImages(
            config: config,
            pipeline: pipeline,
            pipelineConfig: pipelineConfig,
            collector: collector,
            continuation: continuation
        )

        continuation.finish()
        logger.info("Generation completed")
    }
}
