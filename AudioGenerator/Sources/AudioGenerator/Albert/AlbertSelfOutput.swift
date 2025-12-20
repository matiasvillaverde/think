import Foundation
import MLX
import MLXNN

internal class AlbertSelfOutput {
    let dense: Linear
    let layerNorm: LayerNorm

    init(config: AlbertModelArgs) {
        dense = Linear(config.hiddenSize, config.hiddenSize)
        layerNorm = LayerNorm(
            dimensions: config.hiddenSize,
            eps: config.layerNormEps
        )
    }

    func callAsFunction(
        _ hiddenStates: MLXArray,
        inputTensor: MLXArray
    ) -> MLXArray {
        var output: MLXArray = dense(hiddenStates)
        output = layerNorm(output + inputTensor)
        return output
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
