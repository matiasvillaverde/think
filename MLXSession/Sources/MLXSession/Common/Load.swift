// Copyright © 2024 Apple Inc.

import Foundation
import Hub
import MLX
import MLXNN
import OSLog
import Tokenizers

/// Download the model using the `HubApi`.
///
/// This will download `*.safetensors` and `*.json` if the ``ModelConfiguration``
/// represents a Hub id, e.g. `mlx-community/gemma-2-2b-it-4bit`.
///
/// This is typically called via ``ModelFactory/load(hub:configuration:progressHandler:)``
///
/// - Parameters:
///   - hub: HubApi instance
///   - configuration: the model identifier
///   - progressHandler: callback for progress
/// - Returns: URL for the directory containing downloaded files
internal func downloadModel(
    hub: HubApi, configuration: ModelConfiguration,
    progressHandler: @Sendable @escaping (Progress) -> Void
) async throws -> URL {
    let logger = Logger(subsystem: "MLXSession", category: "ModelDownload")
    
    do {
        switch configuration.id {
        case .id(let id, let revision):
            logger.info("Downloading model: \(id) (revision: \(revision))")
            // download the model weights
            let repo = Hub.Repo(id: id)
            let modelFiles = ["*.safetensors", "*.json"]
            let url = try await hub.snapshot(
                from: repo,
                revision: revision,
                matching: modelFiles,
                progressHandler: progressHandler
            )
            logger.info("Model downloaded successfully to: \(url.path)")
            return url
        case .directory(let directory):
            logger.debug("Using local model directory: \(directory.path)")
            return directory
        }

    } catch Hub.HubClientError.authorizationRequired {
        // an authorizationRequired means (typically) that the named repo doesn't exist on
        // on the server so retry with local only configuration
        logger.warning("Authorization required or model not found, falling back to local directory")
        return configuration.modelDirectory(hub: hub)

    } catch {
        let nserror = error as NSError
        if nserror.domain == NSURLErrorDomain && nserror.code == NSURLErrorNotConnectedToInternet {
            // Error Domain=NSURLErrorDomain Code=-1009 "The Internet connection appears to be offline."
            // fall back to the local directory
            logger.warning("No internet connection, using local model directory")
            return configuration.modelDirectory(hub: hub)
        } else {
            logger.error("Failed to download model: \(error.localizedDescription)")
            throw error
        }
    }
}

/// Load model weights.
///
/// This is typically called via ``ModelFactory/load(hub:configuration:progressHandler:)``.
/// This function loads all `safetensor` files in the given `modelDirectory`,
/// calls ``LanguageModel/sanitize(weights:)``, applies optional quantization, and
/// updates the model with the weights.
internal func loadWeights(
    modelDirectory: URL, model: LanguageModel,
    quantization: BaseConfiguration.Quantization? = nil,
    perLayerQuantization: BaseConfiguration.PerLayerQuantization? = nil
) throws {
    let logger = Logger(subsystem: "MLXSession", category: "ModelWeights")
    logger.info("Loading model weights from: \(modelDirectory.path)")
    
    // load the weights
    var weights = [String: MLXArray]()
    var fileCount = 0
    let enumerator = FileManager.default.enumerator(
        at: modelDirectory, includingPropertiesForKeys: nil)!
    for case let url as URL in enumerator {
        if url.pathExtension == "safetensors" {
            logger.debug("Loading weights from: \(url.lastPathComponent)")
            let w = try loadArrays(url: url)
            for (key, value) in w {
                weights[key] = value
            }
            fileCount += 1
        }
    }
    logger.debug("Loaded \(fileCount) safetensor files with \(weights.count) total weights")

    // per-model cleanup
    weights = model.sanitize(weights: weights)
    stripMXFP4QuantizationBiases(
        weights: &weights,
        quantization: quantization,
        perLayerQuantization: perLayerQuantization
    )

    // quantize if needed
    if quantization != nil || perLayerQuantization != nil {
        logger.debug("Applying quantization to model")
        quantize(
            model: model,
            filter: { path, _ in
                guard weights["\(path).scales"] != nil else { return nil }
                if let perLayerQuantization, let perLayer = perLayerQuantization.quantization(layer: path)
                {
                    return (
                        perLayer.groupSize,
                        perLayer.bits,
                        quantizationMode(for: perLayer)
                    )
                }
                if let quantization {
                    return (
                        quantization.groupSize,
                        quantization.bits,
                        quantizationMode(for: quantization)
                    )
                }
                return nil
            },
            apply: quantizeApplyingMode(module:groupSize:bits:mode:)
        )
    }

    // apply the loaded weights
    let parameters = ModuleParameters.unflattened(weights)
    let verify: Module.VerifyUpdate
    if containsNonAffineQuantization(
        quantization: quantization,
        perLayerQuantization: perLayerQuantization
    ) {
        logger.warning("Non-affine quantization detected; allowing missing parameters during update")
        verify = [.noUnusedKeys, .shapeMismatch]
    } else {
        verify = [.all]
    }
    try model.update(parameters: parameters, verify: verify)

    eval(model)
    logger.info("Model weights loaded successfully")
}

internal func quantizationMode(
    for quantization: BaseConfiguration.Quantization
) -> QuantizationMode {
    guard let rawMode = quantization.quantizationMode?.lowercased(),
        let mode = QuantizationMode(rawValue: rawMode) else {
        return .affine
    }
    return mode
}

private func containsNonAffineQuantization(
    quantization: BaseConfiguration.Quantization?,
    perLayerQuantization: BaseConfiguration.PerLayerQuantization?
) -> Bool {
    if let quantization, quantizationMode(for: quantization) != .affine {
        return true
    }
    guard let perLayerQuantization else { return false }
    if let defaultQuantization = perLayerQuantization.quantization,
        quantizationMode(for: defaultQuantization) != .affine {
        return true
    }
    return perLayerQuantization.perLayerQuantization.values.contains { option in
        switch option {
        case .skip:
            return false
        case .quantize(let perLayer):
            return quantizationMode(for: perLayer) != .affine
        }
    }
}

internal func quantizeApplyingMode(
    module: Module,
    groupSize: Int,
    bits: Int,
    mode: QuantizationMode
) -> Module? {
    if module is Quantized {
        return nil
    }

    if let linear = module as? Linear {
        let (weight, scales, biases) = MLX.quantized(
            linear.weight,
            groupSize: groupSize,
            bits: bits,
            mode: mode
        )
        return QuantizedLinear(
            weight: weight,
            bias: linear.bias,
            scales: scales,
            biases: biases,
            groupSize: groupSize,
            bits: bits,
            mode: mode
        )
    }

    return quantizeSingle(layer: module, groupSize: groupSize, bits: bits, mode: mode)
}

private func stripMXFP4QuantizationBiases(
    weights: inout [String: MLXArray],
    quantization: BaseConfiguration.Quantization?,
    perLayerQuantization: BaseConfiguration.PerLayerQuantization?
) {
    if let quantization, isMXFP4(quantization) {
        removeQuantizationBiases(from: &weights)
        return
    }

    guard let perLayerQuantization else { return }
    if let defaultQuantization = perLayerQuantization.quantization, isMXFP4(defaultQuantization) {
        removeQuantizationBiases(from: &weights)
        return
    }

    for (layer, option) in perLayerQuantization.perLayerQuantization {
        guard case .quantize(let quantization) = option, isMXFP4(quantization) else { continue }
        weights["\(layer).biases"] = nil
    }
}

private func removeQuantizationBiases(from weights: inout [String: MLXArray]) {
    let keysToRemove = weights.keys.filter { $0.hasSuffix(".biases") }
    for key in keysToRemove {
        weights[key] = nil
    }
}

private func isMXFP4(_ quantization: BaseConfiguration.Quantization) -> Bool {
    quantization.quantizationMode?.lowercased() == "mxfp4"
}
