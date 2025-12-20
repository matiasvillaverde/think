import Abstractions
import CoreGraphics
import CoreML
import Foundation
import os.log

/// Main image generator using Apple's ml-stable-diffusion pipeline
public actor ImageGenerator: ImageGenerating {
    // MARK: - Properties

    internal static let xlScaleFactor: Float = 0.130_25

    internal let logger: Logger = Logger(
        subsystem: "ImageGenerator",
        category: "ImageGenerator"
    )

    internal var pipelines: [UUID: any StableDiffusionPipelineProtocol] = [:]
    internal var currentTasks: [UUID: Task<Void, Error>] = [:]
    internal let modelDownloader: ModelDownloaderProtocol
    internal var metricsCollectors: [UUID: ImageMetricsCollector] = [:]

    // MARK: - Initialization

    /// Creates a new ImageGenerator instance
    public init(modelDownloader: ModelDownloaderProtocol) {
        self.modelDownloader = modelDownloader
        logger.info("ImageGenerator initialized with ModelDownloader")
    }

    // MARK: - ImageGenerating Protocol

    /// Loads a Stable Diffusion model
    ///
    /// - Parameter model: The model to load
    /// - Returns: Stream of loading progress updates
    public func load(
        model: SendableModel
    ) -> AsyncThrowingStream<ImageGenerationProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await performLoad(
                        model: model,
                        continuation: continuation
                    )
                } catch {
                    logger.error("Failed to load model \(model.id): \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Stops the current generation task for the given model
    ///
    /// - Parameter model: The model to stop generation for
    /// - Throws: Any errors during task cancellation
    public func stop(model: UUID) async throws {
        await withCheckedContinuation { continuation in
            if let task = currentTasks[model] {
                task.cancel()
                currentTasks[model] = nil
            }
            continuation.resume()
        }
    }

    /// Generates images using the loaded model
    ///
    /// - Parameters:
    ///   - model: The model to use for generation
    ///   - config: Configuration for image generation
    /// - Returns: Stream of generation progress with images and statistics
    public func generate(
        model: SendableModel,
        config: ImageConfiguration
    ) -> AsyncThrowingStream<ImageGenerationProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task<Void, Error> {
                do {
                    try await performGenerate(
                        model: model,
                        config: config,
                        continuation: continuation
                    )
                } catch {
                    logger.error("Failed to generate image: \(error)")
                    continuation.finish(throwing: error)
                }
            }
            currentTasks[model.id] = task
        }
    }

    /// Unloads a model from memory
    ///
    /// - Parameter model: The model to unload
    /// - Throws: Any errors during unloading
    public func unload(model: UUID) async throws {
        await withCheckedContinuation { continuation in
            pipelines[model] = nil
            currentTasks[model] = nil
            metricsCollectors[model] = nil
            logger.info("Unloaded model \(model)")
            continuation.resume()
        }
    }
}
