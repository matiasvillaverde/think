import CoreML
import Foundation

/// U-Net noise prediction model for stable diffusion
@available(iOS 16.2, macOS 13.1, *)
public struct Unet: ResourceManaging {
    /// Model used to predict noise residuals given an input, diffusion time step, and conditional embedding
    ///
    /// It can be in the form of a single model or multiple stages
    var models: [ManagedMLModel]

    /// Creates a U-Net noise prediction model
    ///
    /// - Parameters:
    ///   - url: Location of single U-Net  compiled Core ML model
    ///   - configuration: Configuration to be used when the model is loaded
    /// - Returns: U-net model that will lazily load its required resources when needed or requested
    public init(modelAt url: URL,
                configuration: MLModelConfiguration) {
        self.models = [ManagedMLModel(modelAt: url, configuration: configuration)]
    }

    /// Creates a U-Net noise prediction model
    ///
    /// - Parameters:
    ///   - urls: Location of chunked U-Net via urls to each compiled chunk
    ///   - configuration: Configuration to be used when the model is loaded
    /// - Returns: U-net model that will lazily load its required resources when needed or requested
    public init(chunksAt urls: [URL],
                configuration: MLModelConfiguration) {
        self.models = urls.map { ManagedMLModel(modelAt: $0, configuration: configuration) }
    }

    /// Load resources.
    public func loadResources() throws {
        for model in models {
            try model.loadResources()
        }
    }

    /// Unload the underlying model to free up memory
    public func unloadResources() {
        for model in models {
            model.unloadResources()
        }
    }

    /// Pre-warm resources
    public func prewarmResources() throws {
        // Override default to pre-warm each model
        for model in models {
            try model.loadResources()
            model.unloadResources()
        }
    }

    var latentSampleDescription: MLFeatureDescription {
        get throws {
            guard let firstModel = models.first else {
                throw ImageGeneratorError.modelNotLoaded
            }
            return try firstModel.perform { model in
                guard let description = model.modelDescription.inputDescriptionsByName["sample"] else {
                    throw ImageGeneratorError.invalidConfiguration(reason: "Model is missing 'sample' input")
                }
                return description
            }
        }
    }

    /// The expected shape of the models latent sample input
    public var latentSampleShape: [Int] {
        get throws {
            let description = try latentSampleDescription
            guard let constraint = description.multiArrayConstraint else {
                throw ImageGeneratorError.invalidConfiguration(reason: "Latent sample is not a multi-array")
            }
            return constraint.shape.map(\.intValue)
        }
    }

    var latentTimeIdDescription: MLFeatureDescription {
        get throws {
            guard let firstModel = models.first else {
                throw ImageGeneratorError.modelNotLoaded
            }
            return try firstModel.perform { model in
                guard let description = model.modelDescription.inputDescriptionsByName["time_ids"] else {
                    throw ImageGeneratorError.invalidConfiguration(reason: "Model is missing 'time_ids' input")
                }
                return description
            }
        }
    }

    /// The expected shape of the geometry conditioning
    public var latentTimeIdShape: [Int] {
        get throws {
            let description = try latentTimeIdDescription
            guard let constraint = description.multiArrayConstraint else {
                throw ImageGeneratorError.invalidConfiguration(reason: "Time IDs is not a multi-array")
            }
            return constraint.shape.map(\.intValue)
        }
    }

    /// Batch prediction noise from latent samples
    ///
    /// - Parameters:
    ///   - latents: Batch of latent samples in an array
    ///   - timeStep: Current diffusion timestep
    ///   - hiddenStates: Hidden state to condition on
    /// - Returns: Array of predicted noise residuals
    func predictNoise(
        latents: [MLShapedArray<Float32>],
        timeStep: Int,
        hiddenStates: MLShapedArray<Float32>,
        additionalResiduals: [[String: MLShapedArray<Float32>]]? = nil
    ) throws -> [MLShapedArray<Float32>] {
        let t = prepareTimeStep(timeStep: timeStep, hiddenStates: hiddenStates)
        let batch = try prepareBatchInputs(
            latents: latents,
            timeStep: t,
            hiddenStates: hiddenStates,
            additionalResiduals: additionalResiduals
        )
        let results = try models.predictions(from: batch)
        return extractNoiseResults(from: results)
    }

    /// Prepares time step array based on hidden states shape
    private func prepareTimeStep(timeStep: Int, hiddenStates: MLShapedArray<Float32>) -> MLShapedArray<Float32> {
        if hiddenStates.shape[0] == 2 {
            return MLShapedArray(scalars: [Float(timeStep), Float(timeStep)], shape: [2])
        } else {
            return MLShapedArray(scalars: [Float(timeStep)], shape: [1])
        }
    }

    /// Prepares batch inputs for model
    private func prepareBatchInputs(
        latents: [MLShapedArray<Float32>],
        timeStep: MLShapedArray<Float32>,
        hiddenStates: MLShapedArray<Float32>,
        additionalResiduals: [[String: MLShapedArray<Float32>]]?
    ) throws -> MLArrayBatchProvider {
        let inputs = try latents.enumerated().map {
            var dict: [String: Any] = [
                "sample": MLMultiArray($0.element),
                "timestep": MLMultiArray(timeStep),
                "encoder_hidden_states": MLMultiArray(hiddenStates)
            ]
            if let residuals = additionalResiduals?[$0.offset] {
                for (k, v) in residuals {
                    dict[k] = MLMultiArray(v)
                }
            }
            return try MLDictionaryFeatureProvider(dictionary: dict)
        }
        return MLArrayBatchProvider(array: inputs)
    }

    /// Extracts noise results from predictions
    private func extractNoiseResults(from results: MLBatchProvider) -> [MLShapedArray<Float32>] {
        return (0..<results.count).map { i in
            let result = results.features(at: i)
            let outputName = result.featureNames.first!
            let outputNoise = result.featureValue(for: outputName)!.multiArrayValue!

            // To conform to this func return type make sure we return float32
            // Use the fact that the concatenating constructor for MLMultiArray
            // can do type conversion:
            let fp32Noise = MLMultiArray(
                concatenating: [outputNoise],
                axis: 0,
                dataType: .float32
            )
            return MLShapedArray<Float32>(fp32Noise)
        }
    }

    /// Batch prediction noise from latent samples, for Stable Diffusion XL
    ///
    /// - Parameters:
    ///   - latents: Batch of latent samples in an array
    ///   - timeStep: Current diffusion timestep
    ///   - hiddenStates: Hidden state to condition on
    ///   - pooledStates: Additional text states to condition on
    ///   - geometryConditioning: Condition on image geometry
    /// - Returns: Array of predicted noise residuals
    @available(iOS 17.0, macOS 14.0, *)
    func predictNoise(
        latents: [MLShapedArray<Float32>],
        timeStep: Int,
        hiddenStates: MLShapedArray<Float32>,
        pooledStates: MLShapedArray<Float32>,
        geometryConditioning: MLShapedArray<Float32>
    ) throws -> [MLShapedArray<Float32>] {
        // Match time step batch dimension to the model / latent samples
        let t = MLShapedArray<Float32>(scalars: [Float(timeStep), Float(timeStep)], shape: [2])

        // Form batch input to model
        let inputs = try latents.map {
            let dict: [String: Any] = [
                "sample": MLMultiArray($0),
                "timestep": MLMultiArray(t),
                "encoder_hidden_states": MLMultiArray(hiddenStates),
                "text_embeds": MLMultiArray(pooledStates),
                "time_ids": MLMultiArray(geometryConditioning)
            ]
            return try MLDictionaryFeatureProvider(dictionary: dict)
        }
        let batch = MLArrayBatchProvider(array: inputs)

        // Make predictions
        let results = try models.predictions(from: batch)

        // Pull out the results in Float32 format
        return (0..<results.count).map { i in
            let result = results.features(at: i)
            let outputName = result.featureNames.first!

            let outputNoise = result.featureValue(for: outputName)!.multiArrayValue!

            // To conform to this func return type make sure we return float32
            // Use the fact that the concatenating constructor for MLMultiArray
            // can do type conversion:
            let fp32Noise = MLMultiArray(
                concatenating: [outputNoise],
                axis: 0,
                dataType: .float32
            )
            return MLShapedArray<Float32>(fp32Noise)
        }
    }
}
