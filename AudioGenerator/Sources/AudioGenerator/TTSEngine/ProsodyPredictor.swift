// swiftlint:disable force_unwrapping
import Foundation
import MLX
import MLXNN

// Prosody Predictor from StyleTTS2
internal class ProsodyPredictor {
    let shared: LSTM
    let fundamentalFreq: [AdainResBlk1d]
    let noiseModel: [AdainResBlk1d]
    let f0Projection: Conv1dInference
    let noiseProjection: Conv1dInference

    init(weights: [String: MLXArray], styleDim: Int, dHid: Int) {
        shared = LSTM(
            inputSize: dHid + styleDim,
            hiddenSize: dHid / 2,
            wxForward: weights["predictor.shared.weight_ih_l0"]!,
            whForward: weights["predictor.shared.weight_hh_l0"]!,
            biasIhForward: weights["predictor.shared.bias_ih_l0"]!,
            biasHhForward: weights["predictor.shared.bias_hh_l0"]!,
            wxBackward: weights["predictor.shared.weight_ih_l0_reverse"]!,
            whBackward: weights["predictor.shared.weight_hh_l0_reverse"]!,
            biasIhBackward: weights["predictor.shared.bias_ih_l0_reverse"]!,
            biasHhBackward: weights["predictor.shared.bias_hh_l0_reverse"]!
        )

        fundamentalFreq = [
            AdainResBlk1d(weights: weights, weightKeyPrefix: "predictor.F0.0", dimIn: dHid, dimOut: dHid, styleDim: styleDim),
            AdainResBlk1d(weights: weights, weightKeyPrefix: "predictor.F0.1", dimIn: dHid, dimOut: dHid / 2, styleDim: styleDim, upsample: "true"),
            AdainResBlk1d(weights: weights, weightKeyPrefix: "predictor.F0.2", dimIn: dHid / 2, dimOut: dHid / 2, styleDim: styleDim)
        ]

        noiseModel = [
            AdainResBlk1d(weights: weights, weightKeyPrefix: "predictor.N.0", dimIn: dHid, dimOut: dHid, styleDim: styleDim),
            AdainResBlk1d(weights: weights, weightKeyPrefix: "predictor.N.1", dimIn: dHid, dimOut: dHid / 2, styleDim: styleDim, upsample: "true"),
            AdainResBlk1d(weights: weights, weightKeyPrefix: "predictor.N.2", dimIn: dHid / 2, dimOut: dHid / 2, styleDim: styleDim)
        ]

        f0Projection = Conv1dInference(
            inputChannels: dHid / 2,
            outputChannels: 1,
            kernelSize: 1,
            padding: 0,
            weight: weights["predictor.F0_proj.weight"]!,
            bias: weights["predictor.F0_proj.bias"]!
        )

        noiseProjection = Conv1dInference(
            inputChannels: dHid / 2,
            outputChannels: 1,
            kernelSize: 1,
            padding: 0,
            weight: weights["predictor.N_proj.weight"]!,
            bias: weights["predictor.N_proj.bias"]!
        )
    }

    func F0NTrain(x: MLXArray, s: MLXArray) -> (MLXArray, MLXArray) {
        let (sharedOutput, _): (MLXArray, ((MLXArray, MLXArray), (MLXArray, MLXArray))) = shared(x.transposed(0, 2, 1))

        // F0 prediction
        var f0Value: MLXArray = sharedOutput.transposed(0, 2, 1)
        for block in fundamentalFreq {
            f0Value = block(x: f0Value, s: s)
        }
        f0Value = MLX.swappedAxes(f0Value, 2, 1)
        f0Value = f0Projection(f0Value)
        f0Value = MLX.swappedAxes(f0Value, 2, 1)

        // N prediction
        var noiseValue: MLXArray = sharedOutput.transposed(0, 2, 1)
        for block in noiseModel {
            noiseValue = block(x: noiseValue, s: s)
        }
        noiseValue = MLX.swappedAxes(noiseValue, 2, 1)
        noiseValue = noiseProjection(noiseValue)
        noiseValue = MLX.swappedAxes(noiseValue, 2, 1)

        return (f0Value.squeezed(axis: 1), noiseValue.squeezed(axis: 1))
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
// swiftlint:enable force_unwrapping
