import Foundation
import MLX
import MLXNN

// Custom Albert Model
internal class CustomAlbert {
    let config: AlbertModelArgs
    let embeddings: AlbertEmbeddings
    let encoder: AlbertEncoder
    let pooler: Linear

    init(weights: [String: MLXArray], config: AlbertModelArgs) {
        self.config = config
        embeddings = AlbertEmbeddings(weights: weights, config: config)
        encoder = AlbertEncoder(weights: weights, config: config)
        guard let poolerWeight = weights["bert.pooler.weight"],
            let poolerBias = weights["bert.pooler.bias"] else {
            fatalError("Missing required bert.pooler weights")
        }
        pooler = Linear(weight: poolerWeight, bias: poolerBias)
    }

    func callAsFunction(
        _ inputIds: MLXArray,
        tokenTypeIds: MLXArray? = nil,
        attentionMask: MLXArray? = nil
    ) -> (sequenceOutput: MLXArray, pooledOutput: MLXArray) {
        let embeddingOutput: MLXArray = embeddings(inputIds, tokenTypeIds: tokenTypeIds)

        var attentionMaskProcessed: MLXArray?
        if let attentionMask {
            let shape: [Int] = attentionMask.shape
            let newDims: [Int] = [shape[0], 1, 1, shape[1]]
            let reshapedMask: MLXArray = attentionMask.reshaped(newDims)
            attentionMaskProcessed = (1.0 - reshapedMask) * -10_000.0
        }

        let sequenceOutput: MLXArray = encoder(embeddingOutput, attentionMask: attentionMaskProcessed)
        let firstTokenReshaped: MLXArray = sequenceOutput[0..., 0, 0...]
        let pooledOutput: MLXArray = MLX.tanh(pooler(firstTokenReshaped))

        return (sequenceOutput, pooledOutput)
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
