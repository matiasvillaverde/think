import Abstractions
import CoreGraphics
import CoreML
import Foundation
import os.log

extension ImageGenerator {
    // MARK: - Helper Methods

    internal func generateImages(
        config: ImageConfiguration,
        pipeline: any StableDiffusionPipelineProtocol,
        pipelineConfig: StableDiffusionPipeline.Configuration,
        collector: ImageMetricsCollector,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) async throws {
        var currentConfig = pipelineConfig

        for imageIndex in 0..<config.imageCount {
            logger.info(
                "Generating image \(imageIndex + 1) of \(config.imageCount)"
            )

            let singleImageConfig = SingleImageGenerationConfig(
                pipeline: pipeline,
                pipelineConfig: currentConfig,
                imageIndex: imageIndex,
                totalImages: config.imageCount,
                prompt: config.prompt
            )

            try await generateSingleImage(
                config: singleImageConfig,
                collector: collector,
                continuation: continuation
            )

            currentConfig.seed += 1
        }
    }

    internal func createXLPipeline(
        modelURL: URL,
        configuration: MLModelConfiguration
    ) throws -> any StableDiffusionPipelineProtocol {
        try StableDiffusionXLPipeline(
            resourcesAt: modelURL,
            configuration: configuration,
            reduceMemory: false
        )
    }

    internal func createStandardPipeline(
        modelURL: URL,
        configuration: MLModelConfiguration
    ) throws -> any StableDiffusionPipelineProtocol {
        try StableDiffusionPipeline(
            resourcesAt: modelURL,
            controlNet: [],
            configuration: configuration,
            disableSafety: true,
            reduceMemory: false
        )
    }

    internal func createPipeline(
        isXL: Bool,
        modelURL: URL,
        configuration: MLModelConfiguration,
        continuation: AsyncThrowingStream<
            ImageGenerationProgress, Error
        >.Continuation
    ) throws -> any StableDiffusionPipelineProtocol {
        if isXL {
            logger.info("Loading SDXL pipeline")
            continuation.yield(.init(
                stage: .loadingUnet,
                description: "Loading SDXL model"
            ))
            return try createXLPipeline(
                modelURL: modelURL,
                configuration: configuration
            )
        }

        logger.info("Loading standard SD pipeline")
        continuation.yield(.init(
            stage: .loadingUnet,
            description: "Loading SD model"
        ))
        return try createStandardPipeline(
            modelURL: modelURL,
            configuration: configuration
        )
    }

    internal func createPipelineConfiguration(
        from config: ImageConfiguration,
        pipeline: any StableDiffusionPipelineProtocol
    ) -> StableDiffusionPipeline.Configuration {
        var pipelineConfig = StableDiffusionPipeline.Configuration(
            prompt: config.prompt
        )

        pipelineConfig.negativePrompt = config.negativePrompt
        pipelineConfig.stepCount = config.steps
        pipelineConfig.seed = config.seed == 0
            ? UInt32.random(in: 0..<UInt32.max)
            : UInt32(config.seed)
        pipelineConfig.guidanceScale = config.cfgWeight
        pipelineConfig.schedulerType = .pndmScheduler

        // Set scale factors based on model type
        if pipeline is StableDiffusionXLPipeline {
            pipelineConfig.encoderScaleFactor = Self.xlScaleFactor
            pipelineConfig.decoderScaleFactor = Self.xlScaleFactor
            pipelineConfig.schedulerTimestepSpacing = .karras
        }

        return pipelineConfig
    }

    /// Configuration for single image generation
    internal struct SingleImageGenerationConfig {
        let pipeline: any StableDiffusionPipelineProtocol
        let pipelineConfig: StableDiffusionPipeline.Configuration
        let imageIndex: Int
        let totalImages: Int
        let prompt: String
    }

    internal func generateSingleImage(
        config: SingleImageGenerationConfig,
        collector: ImageMetricsCollector,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) async throws {
        // Track timing metrics for first image
        if config.imageIndex == 0 {
            await initializeCollectorForGeneration(
                collector: collector,
                prompt: config.prompt
            )
        }

        let images = try performImageGeneration(
            config: config,
            collector: collector,
            continuation: continuation
        )

        // Yield final images with metrics
        await finalizeGeneration(
            images: images,
            config: config,
            collector: collector,
            continuation: continuation
        )
    }

    private func initializeCollectorForGeneration(
        collector: ImageMetricsCollector,
        prompt: String
    ) async {
        await collector.startPromptEncoding()
        await collector.setTokenCounts(prompt: prompt.count)
        await collector.endPromptEncoding()
        await collector.startDenoising()
    }

    private func performImageGeneration(
        config: SingleImageGenerationConfig,
        collector: ImageMetricsCollector,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) throws -> [CGImage?] {
        let yieldInterval = 5
        var lastYieldedStep = -yieldInterval

        return try config.pipeline.generateImages(
            configuration: config.pipelineConfig
        ) { progress in
            Task {
                await collector.recordDenoisingStep()
            }
            self.handleIntermediateProgress(
                progress: progress,
                lastYieldedStep: &lastYieldedStep,
                yieldInterval: yieldInterval,
                continuation: continuation
            )
            return !Task.isCancelled
        }
    }

    private func finalizeGeneration(
        images: [CGImage?],
        config: SingleImageGenerationConfig,
        collector: ImageMetricsCollector,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) async {
        await collector.startVAEDecoding()
        await collector.endVAEDecoding()
        await yieldFinalImages(
            images: images,
            config: config,
            collector: collector,
            continuation: continuation
        )
    }

    private func handleIntermediateProgress(
        progress: PipelineProgress,
        lastYieldedStep: inout Int,
        yieldInterval: Int,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) {
        let shouldYield = progress.step - lastYieldedStep >= yieldInterval ||
                         progress.step == progress.stepCount - 1

        if shouldYield, !progress.currentImages.isEmpty {
            lastYieldedStep = progress.step
            yieldIntermediateImage(
                progress: progress,
                continuation: continuation
            )
        }
    }

    private func yieldIntermediateImage(
        progress: PipelineProgress,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) {
        guard let firstImage = progress.currentImages.first,
              let cgImage = firstImage,
              progress.step < progress.stepCount - 1 else { return }

        let progressPercentage = Double(progress.step + 1) / Double(progress.stepCount)
        continuation.yield(ImageGenerationProgress(
            stage: .generating(step: progress.step + 1, totalSteps: progress.stepCount),
            currentImage: cgImage,
            lastStepTime: 0,
            description: "Generating image (step \(progress.step + 1)/\(progress.stepCount))",
            progressPercentage: progressPercentage
        ))
    }

    private func yieldFinalImages(
        images: [CGImage?],
        config: SingleImageGenerationConfig,
        collector: ImageMetricsCollector,
        continuation: AsyncThrowingStream<ImageGenerationProgress, Error>.Continuation
    ) async {
        // Set generation configuration in collector
        // Use targetSize for standard SD models, originalSize for SDXL
        let imageSize = Int(config.pipelineConfig.targetSize)
        await collector.setGenerationConfig(
            width: imageSize,
            height: imageSize,
            steps: config.pipelineConfig.stepCount,
            guidanceScale: config.pipelineConfig.guidanceScale,
            scheduler: String(describing: config.pipelineConfig.schedulerType),
            seed: config.pipelineConfig.seed,
            batchSize: images.count
        )

        // Update memory usage
        let memoryInfo = captureMemoryInfo()
        await collector.updateMemoryUsage(
            active: memoryInfo.active,
            peak: memoryInfo.peak
        )

        // Create final metrics
        let imageMetrics = await collector.createMetrics()

        for image in images {
            guard let image else { continue }

            continuation.yield(ImageGenerationProgress(
                stage: .completed,
                currentImage: image,
                lastStepTime: 0,
                description: "Generation complete",
                progressPercentage: 1.0,
                imageMetrics: imageMetrics
            ))
        }
    }

    /// Capture memory information using ProcessInfo
    private func captureMemoryInfo() -> (active: UInt64, peak: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    intPointer,
                    &count
                )
            }
        }

        if result == KERN_SUCCESS {
            let residentSize = UInt64(info.resident_size)
            logger.debug("Memory captured - resident: \(residentSize / 1024 / 1024)MB")
            return (active: residentSize, peak: residentSize)
        } else {
            logger.warning("Failed to capture memory info, using fallback values")
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            return (active: physicalMemory / 4, peak: physicalMemory / 2)
        }
    }

    internal func isXLModel(at url: URL) throws -> Bool {
        // Check UNet metadata to determine if XL model
        let unetMetadataURL = url.appendingPathComponent("Unet.mlmodelc")
            .appendingPathComponent("metadata.json")

        guard FileManager.default.fileExists(
            atPath: unetMetadataURL.path
        ) else {
            return false
        }

        let data = try Data(contentsOf: unetMetadataURL)

        struct ModelMetadata: Decodable {
            let inputSchema: [[String: String]]
        }

        let metadatas = try JSONDecoder().decode(
            [ModelMetadata].self,
            from: data
        )

        guard let metadata = metadatas.first else {
            return false
        }

        // XL models have time_ids and text_embeds inputs
        let inputNames = metadata.inputSchema.compactMap { $0["name"] }
        return inputNames.contains("time_ids")
            && inputNames.contains("text_embeds")
    }
}
