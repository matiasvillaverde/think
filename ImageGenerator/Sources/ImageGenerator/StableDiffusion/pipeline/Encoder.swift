import CoreML
import Foundation

/// A encoder model which produces latent samples from RGB images
@available(iOS 16.2, macOS 13.1, *)
public struct Encoder: ResourceManaging {
    public enum Error: String, Swift.Error {
        case sampleInputShapeNotCorrect
    }

    /// VAE encoder model + post math and adding noise from schedular
    var model: ManagedMLModel

    /// Create encoder from Core ML model
    ///
    /// - Parameters:
    ///     - url: Location of compiled VAE encoder Core ML model
    ///     - configuration: configuration to be used when the model is loaded
    /// - Returns: An encoder that will lazily load its required resources when needed or requested
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

    /// Prediction queue
    let queue = DispatchQueue(label: "encoder.predict")

    /// Encode image into latent sample
    ///
    ///  - Parameters:
    ///    - image: Input image
    ///    - scaleFactor: scalar multiplier on latents before encoding image
    ///    - random
    ///  - Returns: The encoded latent space as MLShapedArray
    public func encode(
        _ image: CGImage,
        scaleFactor: Float32,
        random: inout RandomSource
    ) throws -> MLShapedArray<Float32> {
        let imageData = try prepareImageData(image)
        let output = try performEncoding(imageData)
        let latent = generateLatentSample(from: output, random: &random)

        // Reference pipeline scales the latent after encoding
        return MLShapedArray<Float32>(
            scalars: latent.scalars.map { $0 * scaleFactor },
            shape: [1] + latent.shape
        )
    }

    /// Prepares image data for encoding
    private func prepareImageData(_ image: CGImage) throws -> MLShapedArray<Float32> {
        let imageData = try image.planarRGBShapedArray(minValue: -1.0, maxValue: 1.0)
        let expectedShape = try inputShape
        guard imageData.shape == expectedShape else {
            // Consider auto resizing and croping similar to how Vision or CoreML auto-generated
            // Swift code can accomplish with `MLFeatureValue`
            throw Error.sampleInputShapeNotCorrect
        }
        return imageData
    }

    /// Performs the encoding using the model
    private func performEncoding(_ imageData: MLShapedArray<Float32>) throws -> MLShapedArray<Float32> {
        let name = try inputName
        let dict = [name: MLMultiArray(imageData)]
        let input: MLDictionaryFeatureProvider
        do {
            input = try MLDictionaryFeatureProvider(dictionary: dict)
        } catch {
            throw ImageGeneratorError.featureProviderCreationFailed(
                reason: "Encoder input features",
                underlyingError: error
            )
        }

        let result: MLFeatureProvider
        do {
            result = try model.perform { model in
                try model.prediction(from: input)
            }
        } catch {
            throw ImageGeneratorError.modelExecutionFailed(
                modelType: .encoder,
                underlyingError: error
            )
        }
        guard let outputName = result.featureNames.first,
              let outputValue = result.featureValue(for: outputName)?.multiArrayValue else {
            throw ImageGeneratorError.invalidConfiguration(
                reason: "Encoder output missing expected features"
            )
        }
        return MLShapedArray<Float32>(converting: outputValue)
    }

    /// Generates latent sample using DiagonalGaussianDistribution
    private func generateLatentSample(
        from output: MLShapedArray<Float32>,
        random: inout RandomSource
    ) -> MLShapedArray<Float32> {
        let mean = output[0][0..<4]
        let logvar = MLShapedArray<Float32>(
            scalars: output[0][4..<8].scalars.map { min(max($0, -30), 20) },
            shape: mean.shape
        )
        let std = MLShapedArray<Float32>(
            scalars: logvar.scalars.map { exp(0.5 * $0) },
            shape: logvar.shape
        )
        return MLShapedArray<Float32>(
            scalars: zip(mean.scalars, std.scalars).map {
                Float32(random.nextNormal(mean: Double($0), stdev: Double($1)))
            },
            shape: logvar.shape
        )
    }

    var inputDescription: MLFeatureDescription {
        get throws {
            try model.perform { model in
                guard let firstInput = model.modelDescription.inputDescriptionsByName.first else {
                    throw ImageGeneratorError.invalidConfiguration(
                        reason: "Encoder model has no inputs"
                    )
                }
                return firstInput.value
            }
        }
    }

    var inputName: String {
        get throws {
            try inputDescription.name
        }
    }

    /// The expected shape of the models latent sample input
    var inputShape: [Int] {
        get throws {
            let description = try inputDescription
            guard let constraint = description.multiArrayConstraint else {
                throw ImageGeneratorError.invalidConfiguration(
                    reason: "Encoder input is not a multi-array"
                )
            }
            return constraint.shape.map(\.intValue)
        }
    }
}
