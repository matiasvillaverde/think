import Accelerate
import CoreML
import Foundation

@available(iOS 16.2, macOS 13.1, *)
public struct ControlNet: ResourceManaging {
    var models: [ManagedMLModel]

    public init(modelAt urls: [URL],
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

    var inputImageDescriptions: [MLFeatureDescription] {
        get throws {
            try models.map { model in
                try model.perform { mlModel in
                    guard let description = mlModel.modelDescription.inputDescriptionsByName["controlnet_cond"] else {
                        throw ImageGeneratorError.invalidConfiguration(
                            reason: "ControlNet model missing 'controlnet_cond' input"
                        )
                    }
                    return description
                }
            }
        }
    }

    /// The expected shape of the models image input
    public var inputImageShapes: [[Int]] {
        get throws {
            let descriptions = try inputImageDescriptions
            return try descriptions.map { desc in
                guard let constraint = desc.multiArrayConstraint else {
                    throw ImageGeneratorError.invalidConfiguration(
                        reason: "ControlNet image input is not a multi-array"
                    )
                }
                return constraint.shape.map(\.intValue)
            }
        }
    }

    /// Calculate additional inputs for Unet to generate intended image following provided images
    ///
    /// - Parameters:
    ///   - latents: Batch of latent samples in an array
    ///   - timeStep: Current diffusion timestep
    ///   - hiddenStates: Hidden state to condition on
    ///   - images: Images for each ControlNet
    /// - Returns: Array of predicted noise residuals
    func execute(
        latents: [MLShapedArray<Float32>],
        timeStep: Int,
        hiddenStates: MLShapedArray<Float32>,
        images: [MLShapedArray<Float32>]
    ) throws -> [[String: MLShapedArray<Float32>]] {
        let t = MLShapedArray(scalars: [Float(timeStep), Float(timeStep)], shape: [2])
        var outputs: [[String: MLShapedArray<Float32>]] = []

        for (modelIndex, model) in models.enumerated() {
            let results = try executeModel(
                model: model,
                latents: latents,
                timeStep: t,
                hiddenStates: hiddenStates,
                image: images[modelIndex]
            )

            if outputs.isEmpty {
                outputs = initializeOutputs(latents: latents, results: results)
            }

            try processResults(results: results, outputs: &outputs, modelIndex: modelIndex)
        }

        return outputs
    }

    private func executeModel(
        model: ManagedMLModel,
        latents: [MLShapedArray<Float32>],
        timeStep: MLShapedArray<Float32>,
        hiddenStates: MLShapedArray<Float32>,
        image: MLShapedArray<Float32>
    ) throws -> MLBatchProvider {
        let inputs = try prepareInputs(
            latents: latents,
            timeStep: timeStep,
            hiddenStates: hiddenStates,
            image: image
        )

        do {
            return try model.perform {
                try $0.predictions(fromBatch: inputs)
            }
        } catch {
            throw ImageGeneratorError.modelExecutionFailed(
                modelType: .controlNet,
                underlyingError: error
            )
        }
    }

    private func initializeOutputs(
        latents: [MLShapedArray<Float32>],
        results: MLBatchProvider
    ) -> [[String: MLShapedArray<Float32>]] {
        return initOutputs(
            batch: latents.count,
            shapes: results.features(at: 0).featureValueDictionary
        )
    }

    /// Prepares input batch for model execution
    private func prepareInputs(
        latents: [MLShapedArray<Float32>],
        timeStep: MLShapedArray<Float32>,
        hiddenStates: MLShapedArray<Float32>,
        image: MLShapedArray<Float32>
    ) throws -> MLArrayBatchProvider {
        let inputs = try latents.map { latent in
            let dict: [String: Any] = [
                "sample": MLMultiArray(latent),
                "timestep": MLMultiArray(timeStep),
                "encoder_hidden_states": MLMultiArray(hiddenStates),
                "controlnet_cond": MLMultiArray(image)
            ]
            return try MLDictionaryFeatureProvider(dictionary: dict)
        }
        return MLArrayBatchProvider(array: inputs)
    }

    /// Processes model results and updates outputs
    private func processResults(
        results: MLBatchProvider,
        outputs: inout [[String: MLShapedArray<Float32>]],
        modelIndex: Int
    ) throws {
        for n in 0..<results.count {
            let result = results.features(at: n)
            for k in result.featureNames {
                guard let newValue = result.featureValue(for: k)?.multiArrayValue else {
                    throw ImageGeneratorError.invalidConfiguration(
                        reason: "ControlNet output missing expected feature: \(k)"
                    )
                }
                if modelIndex == 0 {
                    outputs[n][k] = MLShapedArray<Float32>(newValue)
                } else {
                    guard let existingArray = outputs[n][k] else {
                        throw ImageGeneratorError.invalidConfiguration(
                            reason: "ControlNet output array not initialized for key: \(k)"
                        )
                    }
                    addToOutput(
                        newValue: newValue,
                        outputArray: MLMultiArray(existingArray)
                    )
                }
            }
        }
    }

    /// Adds new value to existing output using vDSP
    private func addToOutput(newValue: MLMultiArray, outputArray: MLMultiArray) {
        let count = newValue.count
        let inputPointer = newValue.dataPointer.assumingMemoryBound(to: Float.self)
        let outputPointer = outputArray.dataPointer.assumingMemoryBound(to: Float.self)
        vDSP_vadd(inputPointer, 1, outputPointer, 1, outputPointer, 1, vDSP_Length(count))
    }

    private func initOutputs(batch: Int, shapes: [String: MLFeatureValue]) -> [[String: MLShapedArray<Float32>]] {
        var output: [String: MLShapedArray<Float32>] = [:]
        for (outputName, featureValue) in shapes {
            guard let multiArray = featureValue.multiArrayValue else {
                continue  // Skip non-multiarray outputs
            }
            output[outputName] = MLShapedArray<Float32>(
                repeating: 0.0,
                shape: multiArray.shape.map(\.intValue)
            )
        }
        return Array(repeating: output, count: batch)
    }
}
