import Foundation
@preconcurrency import CoreImage

/// Protocol for Core ML-based image generation.
///
/// This protocol defines the interface for loading and generating images using Core ML models,
/// specifically optimized for Stable Diffusion models on Apple devices.
///
/// ## Example Usage
/// ```swift
/// let generator: any ImageGenerating = ImageGenerator()
/// 
/// // Load a Core ML model
/// for try await progress in generator.load(model: sendableModel) {
///     print("Loading: \(progress)")
/// }
/// 
/// // Generate an image
/// let config = ImageConfiguration(prompt: "A beautiful sunset")
/// for try await (image, stats) in generator.generate(model: sendableModel, config: config) {
///     // Use the generated image
/// }
/// ```
public protocol ImageGenerating: Actor {
    /// Loads a Core ML model for image generation.
    /// 
    /// This method loads the model components (TextEncoder, Unet, VAEDecoder, VAEEncoder)
    /// and prepares them for generation. Progress updates are streamed during loading.
    ///
    /// - Parameter model: The model to load, must have backend type `.coreml`
    /// - Returns: An async stream of loading progress
    /// - Throws: `GeneratorError` if loading fails
    func load(model: SendableModel) -> AsyncThrowingStream<ImageGenerationProgress, Error>

    /// Stops any ongoing generation for the specified model.
    ///
    /// This method cancels the current generation task and cleans up intermediate results.
    /// It's safe to call even if no generation is in progress.
    ///
    /// - Parameter model: The model to stop generation for
    /// - Throws: `GeneratorError` if the model is not loaded
    func stop(model: UUID) async throws

    /// Generates images based on the provided configuration.
    ///
    /// This method performs the full image generation pipeline:
    /// 1. Tokenizes the prompt
    /// 2. Encodes text to embeddings
    /// 3. Runs the diffusion process
    /// 4. Decodes the latent representation to an image
    ///
    /// Progress updates with intermediate images are yielded during generation.
    /// The final yield includes the completed image with generation statistics.
    ///
    /// - Parameters:
    ///   - model: The loaded model to use for generation
    ///   - config: Configuration parameters for the generation
    /// - Returns: An async stream yielding generation progress with images and statistics
    /// - Throws: `GeneratorError` if generation fails
    func generate(model: SendableModel, config: ImageConfiguration) -> AsyncThrowingStream<ImageGenerationProgress, Error>

    /// Unloads the specified model and frees all associated resources.
    ///
    /// This method releases all Core ML models, clears caches, and frees memory.
    /// After unloading, the model must be loaded again before use.
    ///
    /// - Parameter model: The model to unload
    /// - Throws: `GeneratorError` if unloading fails
    func unload(model: UUID) async throws
}
