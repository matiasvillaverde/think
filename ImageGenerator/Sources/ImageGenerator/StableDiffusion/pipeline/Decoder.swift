import CoreML
import Foundation

/// A decoder model which produces RGB images from latent samples
@available(iOS 16.2, macOS 13.1, *)
public struct Decoder: ResourceManaging {
    /// VAE decoder model
    var model: ManagedMLModel

    /// Create decoder from Core ML model
    ///
    /// - Parameters:
    ///     - url: Location of compiled VAE decoder Core ML model
    ///     - configuration: configuration to be used when the model is loaded
    /// - Returns: A decoder that will lazily load its required resources when needed or requested
    public init(modelAt url: URL, configuration: MLModelConfiguration) {
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

    /// Batch decode latent samples into images
    ///
    ///  - Parameters:
    ///    - latents: Batch of latent samples to decode
    ///    - scaleFactor: scalar divisor on latents before decoding
    ///  - Returns: decoded images
    public func decode(
        _ latents: [MLShapedArray<Float32>],
        scaleFactor: Float32,
        shiftFactor: Float32 = 0.0
    ) throws -> [CGImage] {
        let batch = try prepareBatchInput(latents: latents, scaleFactor: scaleFactor, shiftFactor: shiftFactor)
        let results = try performBatchPrediction(batch: batch)
        return try extractImages(from: results)
    }

    private func prepareBatchInput(
        latents: [MLShapedArray<Float32>],
        scaleFactor: Float32,
        shiftFactor: Float32
    ) throws -> MLArrayBatchProvider {
        let name = try inputName
        let inputs: [MLFeatureProvider] = try latents.map { sample in
            let sampleScaled = MLShapedArray<Float32>(
                scalars: sample.scalars.map { $0 / scaleFactor + shiftFactor },
                shape: sample.shape)

            let dict = [name: MLMultiArray(sampleScaled)]
            do {
                return try MLDictionaryFeatureProvider(dictionary: dict)
            } catch {
                throw ImageGeneratorError.featureProviderCreationFailed(
                    reason: "Decoder input features",
                    underlyingError: error
                )
            }
        }
        return MLArrayBatchProvider(array: inputs)
    }

    private func performBatchPrediction(batch: MLArrayBatchProvider) throws -> MLBatchProvider {
        do {
            return try model.perform { model in
                try model.predictions(fromBatch: batch)
            }
        } catch {
            throw ImageGeneratorError.modelExecutionFailed(
                modelType: .decoder,
                underlyingError: error
            )
        }
    }

    private func extractImages(from results: MLBatchProvider) throws -> [CGImage] {
        return try (0..<results.count).map { i in
            let result = results.features(at: i)
            guard let outputName = result.featureNames.first,
                  let output = result.featureValue(for: outputName)?.multiArrayValue else {
                throw ImageGeneratorError.invalidConfiguration(
                    reason: "Decoder output missing expected features"
                )
            }
            do {
                return try CGImage.fromShapedArray(MLShapedArray<Float32>(converting: output))
            } catch {
                throw ImageGeneratorError.imageDecodingFailed(reason: error.localizedDescription)
            }
        }
    }

    var inputName: String {
        get throws {
            try model.perform { model in
                guard let firstInput = model.modelDescription.inputDescriptionsByName.first else {
                    throw ImageGeneratorError.invalidConfiguration(
                        reason: "Decoder model has no inputs"
                    )
                }
                return firstInput.key
            }
        }
    }
}
