import CoreML
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public protocol TextEncoderXLModel: ResourceManaging {
    typealias TextEncoderXLOutput = (hiddenEmbeddings: MLShapedArray<Float32>, pooledOutputs: MLShapedArray<Float32>)
    func encode(_ text: String) throws -> TextEncoderXLOutput
}

///  A model for encoding text, suitable for SDXL
@available(iOS 17.0, macOS 14.0, *)
public struct TextEncoderXL: TextEncoderXLModel {
    /// Text tokenizer
    var tokenizer: BPETokenizer

    /// Embedding model
    var model: ManagedMLModel

    /// Creates text encoder which embeds a tokenized string
    ///
    /// - Parameters:
    ///   - tokenizer: Tokenizer for input text
    ///   - url: Location of compiled text encoding  Core ML model
    ///   - configuration: configuration to be used when the model is loaded
    /// - Returns: A text encoder that will lazily load its required resources when needed or requested
    public init(tokenizer: BPETokenizer,
                modelAt url: URL,
                configuration: MLModelConfiguration) {
        self.tokenizer = tokenizer
        self.model = ManagedMLModel(modelAt: url, configuration: configuration)
    }

    /// Ensure the model has been loaded into memory
    public func loadResources() throws {
        try model.loadResources()
    }

    /// Unload the underlying model to free up memory
    public func unloadResources() {
       model.unloadResources()
    }

    /// Encode input text/string
    ///
    ///  - Parameters:
    ///     - text: Input text to be tokenized and then embedded
    ///  - Returns: Embedding representing the input text
    public func encode(_ text: String) throws -> TextEncoderXLOutput {
        // Get models expected input length
        let shape = try inputShape
        guard let inputLength = shape.last else {
            throw ImageGeneratorError.invalidConfiguration(
                reason: "TextEncoderXL input shape is empty"
            )
        }

        // Tokenize, padding to the expected length
        var (tokens, ids) = tokenizer.tokenize(input: text, minCount: inputLength)

        // Truncate if necessary
        if ids.count > inputLength {
            tokens = tokens.dropLast(tokens.count - inputLength)
            ids = ids.dropLast(ids.count - inputLength)
            // Input was truncated to fit model's maximum token length
        }

        // Use the model to generate the embedding
        return try encode(ids: ids)
    }

    func encode(ids: [Int]) throws -> TextEncoderXLOutput {
        let inputFeatures = try prepareInputFeatures(ids: ids)
        let result = try performPrediction(inputFeatures: inputFeatures)
        return try extractOutputs(from: result)
    }

    private func prepareInputFeatures(ids: [Int]) throws -> MLDictionaryFeatureProvider {
        let inputDesc = try inputDescription
        let inputName = inputDesc.name
        let inputShape = try self.inputShape

        let floatIds = ids.map { Float32($0) }
        let inputArray = MLShapedArray<Float32>(scalars: floatIds, shape: inputShape)

        do {
            return try MLDictionaryFeatureProvider(
                dictionary: [inputName: MLMultiArray(inputArray)])
        } catch {
            throw ImageGeneratorError.featureProviderCreationFailed(
                reason: "TextEncoderXL input features",
                underlyingError: error
            )
        }
    }

    private func performPrediction(inputFeatures: MLDictionaryFeatureProvider) throws -> MLFeatureProvider {
        do {
            return try model.perform { model in
                try model.prediction(from: inputFeatures)
            }
        } catch {
            throw ImageGeneratorError.modelExecutionFailed(
                modelType: .textEncoderXL,
                underlyingError: error
            )
        }
    }

    private func extractOutputs(from result: MLFeatureProvider) throws -> TextEncoderXLOutput {
        guard let embeddingFeature = result.featureValue(for: "hidden_embeds"),
              let embeddingArray = embeddingFeature.multiArrayValue,
              let pooledFeature = result.featureValue(for: "pooled_outputs"),
              let pooledArray = pooledFeature.multiArrayValue else {
            throw ImageGeneratorError.invalidConfiguration(
                reason: "TextEncoderXL output missing required features"
            )
        }
        return (
            MLShapedArray<Float32>(converting: embeddingArray),
            MLShapedArray<Float32>(converting: pooledArray)
        )
    }

    var inputDescription: MLFeatureDescription {
        get throws {
            try model.perform { model in
                guard let firstInput = model.modelDescription.inputDescriptionsByName.first else {
                    throw ImageGeneratorError.invalidConfiguration(
                        reason: "TextEncoderXL model has no inputs"
                    )
                }
                return firstInput.value
            }
        }
    }

    var inputShape: [Int] {
        get throws {
            let description = try inputDescription
            guard let constraint = description.multiArrayConstraint else {
                throw ImageGeneratorError.invalidConfiguration(
                    reason: "TextEncoderXL input is not a multi-array"
                )
            }
            return constraint.shape.map(\.intValue)
        }
    }
}
