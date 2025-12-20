import Foundation
import CoreML
@preconcurrency import CoreImage

/// Configuration for image generation requests.
///
/// This structure contains all parameters needed to generate images using
/// either MLX-based or Core ML-based models.
public struct ImageConfiguration: Sendable {
    // MARK: - Core Properties (existing)
    public let id: UUID
    public let prompt: String
    public let negativePrompt: String
    public let steps: Int
    public let seed: UInt64
    public let cfgWeight: Float
    public let imageCount: Int
    public let decodingBatchSize: Int
    public let latentSize: [Int]

    // MARK: - Core ML Specific Properties

    /// The scheduler algorithm to use for the diffusion process
    public let scheduler: Scheduler

    /// Model attention type configuration
    public let attentionType: ModelAttentionType

    /// Compute units to use for Core ML inference
    public let computeUnits: MLComputeUnits

    /// Whether to reduce memory usage at the cost of performance
    public let reduceMemory: Bool

    /// Output image size (Core ML models may have fixed sizes)
    public let outputSize: CGSize

    /// Whether this is an XL model (affects pipeline selection)
    public let isXLModel: Bool

    /// Starting image for image-to-image generation (optional)
    public let startingImage: CGImage?

    /// Strength for image-to-image generation (0.0-1.0)
    public let strength: Float

    // MARK: - Initialization

    public init(
        prompt: String,
        id: UUID = UUID(),
        negativePrompt: String = "",
        steps: Int = 50,
        seed: UInt64 = 42,
        cfgWeight: Float = 7.5,
        imageCount: Int = 1,
        decodingBatchSize: Int = 1,
        latentSize: [Int] = [64, 64],
        // Core ML specific parameters
        scheduler: Scheduler = .dpmSolverMultistepScheduler,
        attentionType: ModelAttentionType = .automatic,
        computeUnits: MLComputeUnits = .cpuAndGPU,
        reduceMemory: Bool = false,
        outputSize: CGSize = CGSize(width: 512, height: 512),
        isXLModel: Bool = false,
        startingImage: CGImage? = nil,
        strength: Float = 0.75
    ) {
        self.id = id
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.steps = steps
        self.seed = seed
        self.cfgWeight = cfgWeight
        self.imageCount = imageCount
        self.decodingBatchSize = decodingBatchSize
        self.latentSize = latentSize
        self.scheduler = scheduler
        self.attentionType = attentionType
        self.computeUnits = computeUnits
        self.reduceMemory = reduceMemory
        self.outputSize = outputSize
        self.isXLModel = isXLModel
        self.startingImage = startingImage
        self.strength = strength
    }
}
