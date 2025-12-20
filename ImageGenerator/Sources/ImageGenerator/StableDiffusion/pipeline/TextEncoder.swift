import CoreML
import Foundation

@available(iOS 16.2, macOS 13.1, *)
public protocol TextEncoderModel: ResourceManaging {
    func encode(_ text: String) throws -> MLShapedArray<Float32>
}

///  A model for encoding text
@available(iOS 16.2, macOS 13.1, *)
public struct TextEncoder: TextEncoderModel {
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
    public func encode(_ text: String) throws -> MLShapedArray<Float32> {
        // Get models expected input length
        let shape = try inputShape
        guard let inputLength = shape.last else {
            throw ImageGeneratorError.invalidConfiguration(
                reason: "TextEncoder input shape is empty"
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

    /// Prediction queue
    let queue = DispatchQueue(label: "textencoder.predict")

    func encode(ids: [Int]) throws -> MLShapedArray<Float32> {
        let inputFeatures = try prepareInputFeatures(ids: ids)
        let result = try performPrediction(inputFeatures: inputFeatures)
        return try extractEmbedding(from: result)
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
                reason: "TextEncoder input features",
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
                modelType: .textEncoder,
                underlyingError: error
            )
        }
    }

    private func extractEmbedding(from result: MLFeatureProvider) throws -> MLShapedArray<Float32> {
        guard let embeddingFeature = result.featureValue(for: "last_hidden_state"),
              let multiArray = embeddingFeature.multiArrayValue else {
            throw ImageGeneratorError.invalidConfiguration(
                reason: "TextEncoder output missing 'last_hidden_state' feature"
            )
        }
        return MLShapedArray<Float32>(converting: multiArray)
    }

    var inputDescription: MLFeatureDescription {
        get throws {
            try model.perform { model in
                guard let firstInput = model.modelDescription.inputDescriptionsByName.first else {
                    throw ImageGeneratorError.invalidConfiguration(
                        reason: "TextEncoder model has no inputs"
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
                    reason: "TextEncoder input is not a multi-array"
                )
            }
            return constraint.shape.map(\.intValue)
        }
    }
}
