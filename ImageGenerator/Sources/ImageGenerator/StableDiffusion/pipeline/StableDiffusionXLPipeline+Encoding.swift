import CoreML
import Foundation

// MARK: - Model Inputs

@available(iOS 17.0, macOS 14.0, *)
public extension StableDiffusionXLPipeline {
    struct ModelInputs {
        var hiddenStates: MLShapedArray<Float32>
        var pooledStates: MLShapedArray<Float32>
        var geometryConditioning: MLShapedArray<Float32>
    }
}

// MARK: - Encoding Operations

@available(iOS 17.0, macOS 14.0, *)
extension StableDiffusionXLPipeline {
    /// Encodes prompt for base or refiner model
    func encodePrompt(
        _ prompt: String,
        forRefiner: Bool = false
    ) throws -> (MLShapedArray<Float32>, MLShapedArray<Float32>) {
        if forRefiner {
            return try encodeForRefiner(prompt)
        } else {
            return try encodeForBase(prompt)
        }
    }

    /// Encodes prompt for refiner model
    private func encodeForRefiner(_ prompt: String) throws -> (MLShapedArray<Float32>, MLShapedArray<Float32>) {
        let (embeds2, pooledValue) = try textEncoder2.encode(prompt)
        // Refiner only takes textEncoder2 embeddings
        // [1, 77, 1280]
        return (embeds2, pooledValue)
    }

    /// Encodes prompt for base model
    private func encodeForBase(_ prompt: String) throws -> (MLShapedArray<Float32>, MLShapedArray<Float32>) {
        guard let encoder = textEncoder else {
            throw ImageGeneratorError.startingText2ImgWithoutTextEncoder
        }
        let (embeds1, _) = try encoder.encode(prompt)
        let (embeds2, pooledValue) = try textEncoder2.encode(prompt)

        // Base needs concatenated embeddings
        // [1, 77, 768], [1, 77, 1280] -> [1, 77, 2048]
        let embeds = MLShapedArray<Float32>(
            concatenating: [embeds1, embeds2],
            alongAxis: 2
        )
        return (embeds, pooledValue)
    }

    /// Generates conditioning for the model
    func generateConditioning(using config: Configuration, forRefiner: Bool = false) throws -> ModelInputs {
        // Encode the input prompt and negative prompt
        let (promptEmbedding, pooled) = try encodePrompt(config.prompt, forRefiner: forRefiner)
        let (negativePromptEmbedding, negativePooled) = try encodePrompt(config.negativePrompt, forRefiner: forRefiner)

        // Convert to Unet hidden state representation
        // Concatenate the prompt and negative prompt embeddings
        let hiddenStates = toHiddenStates(
            MLShapedArray(concatenating: [negativePromptEmbedding, promptEmbedding], alongAxis: 0)
        )
        let pooledStates = MLShapedArray(concatenating: [negativePooled, pooled], alongAxis: 0)

        let geometry = forRefiner ? createRefinerGeometry(config: config) : try createBaseGeometry(config: config)

        return ModelInputs(hiddenStates: hiddenStates, pooledStates: pooledStates, geometryConditioning: geometry)
    }

    /// Creates geometry conditioning for refiner
    private func createRefinerGeometry(config: Configuration) -> MLShapedArray<Float32> {
        let negativeGeometry = MLShapedArray<Float32>(
            scalars: [
                config.originalSize, config.originalSize,
                config.cropsCoordsTopLeft, config.cropsCoordsTopLeft,
                config.negativeAestheticScore
            ],
            shape: [1, 5]
        )
        let positiveGeometry = MLShapedArray<Float32>(
            scalars: [
                config.originalSize, config.originalSize,
                config.cropsCoordsTopLeft, config.cropsCoordsTopLeft,
                config.aestheticScore
            ],
            shape: [1, 5]
        )
        return MLShapedArray<Float32>(concatenating: [negativeGeometry, positiveGeometry], alongAxis: 0)
    }

    /// Creates geometry conditioning for base model
    private func createBaseGeometry(config: Configuration) throws -> MLShapedArray<Float32> {
        let latentTimeIdShape = try unet.latentTimeIdShape
        let geometry = MLShapedArray<Float32>(
            scalars: [
                config.originalSize, config.originalSize,
                config.cropsCoordsTopLeft, config.cropsCoordsTopLeft,
                config.targetSize, config.targetSize
            ],
            shape: latentTimeIdShape.count > 1 ? [1, 6] : [6]
        )
        return MLShapedArray<Float32>(concatenating: [geometry, geometry], alongAxis: 0)
    }
}

// MARK: - Conditioning Setup

@available(iOS 17.0, macOS 14.0, *)
extension StableDiffusionXLPipeline {
    /// Sets up conditioning for base and refiner models
    func setupConditioning(config: Configuration) throws -> (
        baseInput: ModelInputs?,
        refinerInput: ModelInputs?
    ) {
        let latentTimeIdShape = try unet.latentTimeIdShape
        let isRefiner = latentTimeIdShape.last == 5
        var baseInput: ModelInputs?
        var refinerInput: ModelInputs?

        if textEncoder != nil {
            baseInput = try generateConditioning(using: config, forRefiner: isRefiner)
        }

        if unetRefiner != nil || isRefiner {
            refinerInput = try generateConditioning(using: config, forRefiner: true)
        }

        if reduceMemory {
            textEncoder?.unloadResources()
            textEncoder2.unloadResources()
        }

        return (baseInput, refinerInput)
    }
}
