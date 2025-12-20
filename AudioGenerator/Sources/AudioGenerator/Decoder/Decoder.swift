import Foundation
import MLX
import MLXNN

// swiftlint:disable force_unwrapping

internal class Decoder {
    private let encode: AdainResBlk1d
    private var decode: [AdainResBlk1d] = []
    private let f0Conv: ConvWeighted
    private let noiseConv: ConvWeighted
    private let asrRes: [ConvWeighted]
    private let generator: Generator

    init(
        weights: [String: MLXArray],
        dimIn: Int,
        styleDim: Int,
        dimOut _: Int,
        resblockKernelSizes: [Int],
        upsampleRates: [Int],
        upsampleInitialChannel: Int,
        resblockDilationSizes: [[Int]],
        upsampleKernelSizes: [Int],
        genIstftNFft: Int,
        genIstftHopSize: Int
    ) {
        encode = AdainResBlk1d(weights: weights, weightKeyPrefix: "decoder.encode", dimIn: dimIn + 2, dimOut: 1_024, styleDim: styleDim)

        decode.append(AdainResBlk1d(weights: weights, weightKeyPrefix: "decoder.decode.0", dimIn: 1_024 + 2 + 64, dimOut: 1_024, styleDim: styleDim))
        decode.append(AdainResBlk1d(weights: weights, weightKeyPrefix: "decoder.decode.1", dimIn: 1_024 + 2 + 64, dimOut: 1_024, styleDim: styleDim))
        decode.append(AdainResBlk1d(weights: weights, weightKeyPrefix: "decoder.decode.2", dimIn: 1_024 + 2 + 64, dimOut: 1_024, styleDim: styleDim))
        decode.append(AdainResBlk1d(weights: weights, weightKeyPrefix: "decoder.decode.3", dimIn: 1_024 + 2 + 64, dimOut: 512, styleDim: styleDim, upsample: "true"))

        f0Conv = ConvWeighted(
            weightG: weights["decoder.F0_conv.weight_g"]!,
            weightV: weights["decoder.F0_conv.weight_v"]!,
            bias: weights["decoder.F0_conv.bias"]!,
            stride: 2,
            padding: 1,
            groups: 1
        )
        noiseConv = ConvWeighted(
            weightG: weights["decoder.N_conv.weight_g"]!,
            weightV: weights["decoder.N_conv.weight_v"]!,
            bias: weights["decoder.N_conv.bias"]!,
            stride: 2,
            padding: 1,
            groups: 1
        )

        asrRes = [
            ConvWeighted(
                weightG: weights["decoder.asr_res.0.weight_g"]!,
                weightV: weights["decoder.asr_res.0.weight_v"]!,
                bias: weights["decoder.asr_res.0.bias"]!,
                padding: 0
            )
        ]

        generator = Generator(
            weights: weights,
            styleDim: styleDim,
            resblockKernelSizes: resblockKernelSizes,
            upsampleRates: upsampleRates,
            upsampleInitialChannel: upsampleInitialChannel,
            resblockDilationSizes: resblockDilationSizes,
            upsampleKernelSizes: upsampleKernelSizes,
            genIstftNFft: genIstftNFft,
            genIstftHopSize: genIstftHopSize
        )
    }

    func callAsFunction(asr: MLXArray, F0Curve: MLXArray, N: MLXArray, s: MLXArray) -> MLXArray {
        let f0CurveSwapped: MLXArray = MLX.swappedAxes(F0Curve.reshaped([F0Curve.shape[0], 1, F0Curve.shape[1]]), 2, 1)
        let f0Processed: MLXArray = MLX.swappedAxes(f0Conv(f0CurveSwapped, conv: MLX.conv1d), 2, 1)

        let noiseSwapped: MLXArray = MLX.swappedAxes(N.reshaped([N.shape[0], 1, N.shape[1]]), 2, 1)
        let noiseProcessed: MLXArray = MLX.swappedAxes(noiseConv(noiseSwapped, conv: MLX.conv1d), 2, 1)

        var tensor: MLXArray = MLX.concatenated([asr, f0Processed, noiseProcessed], axis: 1)
        tensor = encode(x: tensor, s: s)

        let asrResidual: MLXArray = MLX.swappedAxes(asrRes[0](MLX.swappedAxes(asr, 2, 1), conv: MLX.conv1d), 2, 1)
        var res: Bool = true

        for block in decode {
            if res {
                tensor = MLX.concatenated([tensor, asrResidual, f0Processed, noiseProcessed], axis: 1)
            }
            tensor = block(x: tensor, s: s)

            if block.upsampleType != "none" {
                res = false
            }
        }

        return generator(tensor, s, F0Curve)
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
// swiftlint:enable force_unwrapping
