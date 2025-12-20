import Foundation
@preconcurrency import CoreImage

/// Represents the progress of an image generation task.
///
/// This structure provides detailed progress information during model loading
/// and image generation, including intermediate results and timing information.
public struct ImageGenerationProgress: Sendable {
    /// The current stage of the generation process
    public let stage: Stage

    /// Optional intermediate image during generation
    public let currentImage: CGImage?

    /// Time taken for the last step (in seconds)
    public let lastStepTime: TimeInterval

    /// Detailed description of the current operation
    public let description: String

    /// Progress percentage (0.0 to 1.0)
    public let progressPercentage: Double

    /// Generation metrics following the unified metrics pattern (only available in completed stage)
    public let imageMetrics: ImageMetrics?

    /// Defines the various stages of image generation
    public enum Stage: Sendable, Equatable, Hashable {
        // Model loading stages
        case loadingTokenizer
        case loadingTextEncoder
        case loadingUnet
        case loadingVAEDecoder
        case loadingVAEEncoder
        case compilingModels
        case detectingMetadata

        // Generation stages
        case tokenizingPrompt
        case encodingText
        case generating(step: Int, totalSteps: Int)
        case decodingLatents
        case postProcessing

        // Completion
        case completed
    }

    public init(
        stage: Stage,
        currentImage: CGImage? = nil,
        lastStepTime: TimeInterval = 0,
        description: String = "",
        progressPercentage: Double = 0,
        imageMetrics: ImageMetrics? = nil
    ) {
        self.stage = stage
        self.currentImage = currentImage
        self.lastStepTime = lastStepTime
        self.description = description.isEmpty ? stage.defaultDescription : description
        self.progressPercentage = progressPercentage
        self.imageMetrics = imageMetrics
    }
}

// MARK: - Default Descriptions

private extension ImageGenerationProgress.Stage {
    var defaultDescription: String {
        switch self {
        case .loadingTokenizer:
            return "Loading tokenizer vocabulary"
        case .loadingTextEncoder:
            return "Loading text encoder model"
        case .loadingUnet:
            return "Loading diffusion model"
        case .loadingVAEDecoder:
            return "Loading image decoder"
        case .loadingVAEEncoder:
            return "Loading image encoder"
        case .compilingModels:
            return "Compiling Core ML models"
        case .detectingMetadata:
            return "Detecting model configuration"
        case .tokenizingPrompt:
            return "Processing text prompt"
        case .encodingText:
            return "Encoding text to embeddings"
        case let .generating(step, total):
            return "Generating image (step \(step)/\(total))"
        case .decodingLatents:
            return "Decoding image data"
        case .postProcessing:
            return "Finalizing image"
        case .completed:
            return "Generation complete"
        }
    }
}
