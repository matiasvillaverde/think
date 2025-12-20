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
        encode = Self.buildEncode(weights: weights, dimIn: dimIn, styleDim: styleDim)
        decode = Self.buildDecode(weights: weights, styleDim: styleDim)
        f0Conv = Self.buildConv(
            weights: weights,
            keyPrefix: "decoder.F0_conv",
            stride: 2,
            padding: 1
        )
        noiseConv = Self.buildConv(
            weights: weights,
            keyPrefix: "decoder.N_conv",
            stride: 2,
            padding: 1
        )
        asrRes = [Self.buildConv(weights: weights, keyPrefix: "decoder.asr_res.0")]

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

    private static func buildEncode(
        weights: [String: MLXArray],
        dimIn: Int,
        styleDim: Int
    ) -> AdainResBlk1d {
        AdainResBlk1d(
            weights: weights,
            weightKeyPrefix: "decoder.encode",
            dimIn: dimIn + 2,
            dimOut: 1_024,
            styleDim: styleDim
        )
    }

    private static func buildDecode(
        weights: [String: MLXArray],
        styleDim: Int
    ) -> [AdainResBlk1d] {
        [
            AdainResBlk1d(
                weights: weights,
                weightKeyPrefix: "decoder.decode.0",
                dimIn: 1_024 + 2 + 64,
                dimOut: 1_024,
                styleDim: styleDim
            ),
            AdainResBlk1d(
                weights: weights,
                weightKeyPrefix: "decoder.decode.1",
                dimIn: 1_024 + 2 + 64,
                dimOut: 1_024,
                styleDim: styleDim
            ),
            AdainResBlk1d(
                weights: weights,
                weightKeyPrefix: "decoder.decode.2",
                dimIn: 1_024 + 2 + 64,
                dimOut: 1_024,
                styleDim: styleDim
            ),
            AdainResBlk1d(
                weights: weights,
                weightKeyPrefix: "decoder.decode.3",
                dimIn: 1_024 + 2 + 64,
                dimOut: 512,
                styleDim: styleDim,
                upsample: "true"
            )
        ]
    }

    private static func buildConv(
        weights: [String: MLXArray],
        keyPrefix: String,
        stride: Int = 1,
        padding: Int = 0,
        groups: Int = 1
    ) -> ConvWeighted {
        ConvWeighted(
            weightG: weights["\(keyPrefix).weight_g"]!,
            weightV: weights["\(keyPrefix).weight_v"]!,
            bias: weights["\(keyPrefix).bias"]!,
            stride: stride,
            padding: padding,
            groups: groups
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
