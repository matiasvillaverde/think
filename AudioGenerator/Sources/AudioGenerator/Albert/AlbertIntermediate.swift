import Foundation
import MLX
import MLXNN

internal class AlbertIntermediate {
    let dense: Linear

    init(config: AlbertModelArgs) {
        dense = Linear(config.hiddenSize, config.intermediateSize)
    }

    func callAsFunction(_ hiddenStates: MLXArray) -> MLXArray {
        var output: MLXArray = dense(hiddenStates)
        output = MLXNN.gelu(output)
        return output
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
