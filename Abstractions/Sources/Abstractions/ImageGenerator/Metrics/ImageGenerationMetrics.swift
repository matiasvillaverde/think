import Foundation

/// Generation-specific metrics for image creation.
///
/// Captures the parameters and configuration used during the Stable Diffusion
/// image generation process for quality analysis and reproducibility.
public struct ImageGenerationMetrics: Sendable, Codable {
    /// Width of the generated image in pixels.
    public let width: Int

    /// Height of the generated image in pixels.
    public let height: Int

    /// Number of denoising steps performed.
    public let steps: Int

    /// Guidance scale (CFG scale) used for generation.
    public let guidanceScale: Float

    /// Random seed used for generation (if specified).
    public let seed: UInt32?

    /// Name of the scheduler algorithm used.
    public let scheduler: String

    /// Name of the model used for generation.
    public let modelName: String

    /// Safety checker status.
    public let safetyCheckPassed: Bool

    /// Number of images generated in the batch.
    public let batchSize: Int

    /// Creates new generation metrics for image creation.
    ///
    /// - Parameters:
    ///   - width: Image width in pixels (required)
    ///   - height: Image height in pixels (required)
    ///   - steps: Number of denoising steps (required)
    ///   - guidanceScale: CFG scale value (required)
    ///   - scheduler: Scheduler algorithm name (required)
    ///   - modelName: Model identifier (required)
    ///   - seed: Optional random seed for reproducibility
    ///   - safetyCheckPassed: Safety check result (defaults to true)
    ///   - batchSize: Number of images generated (defaults to 1)
    public init(
        width: Int,
        height: Int,
        steps: Int,
        guidanceScale: Float,
        scheduler: String,
        modelName: String,
        seed: UInt32? = nil,
        safetyCheckPassed: Bool = true,
        batchSize: Int = 1
    ) {
        self.width = width
        self.height = height
        self.steps = steps
        self.guidanceScale = guidanceScale
        self.seed = seed
        self.scheduler = scheduler
        self.modelName = modelName
        self.safetyCheckPassed = safetyCheckPassed
        self.batchSize = batchSize
    }
}
