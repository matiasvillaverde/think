import Foundation
import MLX
import MLXNN

internal class AdaIN1d {
    private let norm: InstanceNorm1d
    private let fc: Linear

    init(styleDim _: Int, numFeatures: Int, fcWeight: MLXArray, fcBias: MLXArray) {
        norm = InstanceNorm1d(numFeatures: numFeatures, affine: false)
        fc = Linear(weight: fcWeight, bias: fcBias)
    }

    func callAsFunction(_ x: MLXArray, s: MLXArray) -> MLXArray {
        let h: MLXArray = fc(s)
        let hExpanded: MLXArray = h.expandedDimensions(axes: [2])
        let split: [MLXArray] = hExpanded.split(parts: 2, axis: 1)
        let gamma: MLXArray = split[0]
        let beta: MLXArray = split[1]

        let normalized: MLXArray = norm(x)
        return (1 + gamma) * normalized + beta
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
