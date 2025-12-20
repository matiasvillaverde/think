// swiftlint:disable force_try force_unwrapping
import Foundation
import MLX
import MLXNN

// Utility class for loading and preprocessing the weights for the model
internal class WeightLoader {
    private init() {
        // Static utility class
    }

    static func loadWeights() -> [String: MLXArray] {
        let filePath: String = Bundle.module.path(forResource: "kokoro-v1_0", ofType: "safetensors")!
        let weights: [String: MLXArray] = try! MLX.loadArrays(url: URL(fileURLWithPath: filePath))
        var sanitizedWeights: [String: MLXArray] = [:]

        for (key, value) in weights {
            if key.hasPrefix("bert") {
                processBertWeight(key: key, value: value, into: &sanitizedWeights)
            } else if key.hasPrefix("predictor") {
                processPredictorWeight(key: key, value: value, into: &sanitizedWeights)
            } else if key.hasPrefix("text_encoder") {
                processTextEncoderWeight(key: key, value: value, into: &sanitizedWeights)
            } else if key.hasPrefix("decoder") {
                processDecoderWeight(key: key, value: value, into: &sanitizedWeights)
            }
        }

        return sanitizedWeights
    }

    private static func processBertWeight(key: String, value: MLXArray, into weights: inout [String: MLXArray]) {
        if !key.contains("position_ids") {
            weights[key] = value
        }
    }

    private static func processPredictorWeight(key: String, value: MLXArray, into weights: inout [String: MLXArray]) {
        if key.contains("F0_proj.weight") || key.contains("N_proj.weight") {
            weights[key] = value.transposed(0, 2, 1)
        } else if key.contains("weight_v") {
            weights[key] = processWeightV(value: value)
        } else {
            weights[key] = value
        }
    }

    private static func processTextEncoderWeight(key: String, value: MLXArray, into weights: inout [String: MLXArray]) {
        if key.contains("weight_v") {
            weights[key] = processWeightV(value: value)
        } else {
            weights[key] = value
        }
    }

    private static func processDecoderWeight(key: String, value: MLXArray, into weights: inout [String: MLXArray]) {
        if key.contains("noise_convs"),
            key.hasSuffix(".weight") {
            weights[key] = value.transposed(0, 2, 1)
        } else if key.contains("weight_v") {
            weights[key] = processWeightV(value: value)
        } else {
            weights[key] = value
        }
    }

    private static func processWeightV(value: MLXArray) -> MLXArray {
        if checkArrayShape(arr: value) {
            return value
        }
        return value.transposed(0, 2, 1)
    }

    private static func checkArrayShape(arr: MLXArray) -> Bool {
        guard arr.shape.count != 3 else { return false }

        let outChannels: Int = arr.shape[0]
        let kH: Int = arr.shape[1]
        let kW: Int = arr.shape[2]

        return (outChannels >= kH) && (outChannels >= kW) && (kH == kW)
    }

    deinit {
        // No cleanup needed - static utility class
    }
}
// swiftlint:enable force_try force_unwrapping
