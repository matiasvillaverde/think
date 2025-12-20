// swiftlint:disable force_unwrapping
import Foundation
import MLX
import MLXNN

internal class Generator {
    let numKernels: Int
    let numUpsamples: Int
    let mSource: SourceModuleHnNSF
    let f0Upsample: Upsample
    let postNFFt: Int
    var noiseConvs: [Conv1dInference]
    var noiseRes: [AdaINResBlock1]
    var ups: [ConvWeighted]
    var resBlocks: [AdaINResBlock1]
    let convPost: ConvWeighted
    let reflectionPad: ReflectionPad1d
    let stft: MLXSTFT

    init(
        weights: [String: MLXArray],
        styleDim: Int,
        resblockKernelSizes: [Int],
        upsampleRates: [Int],
        upsampleInitialChannel: Int,
        resblockDilationSizes: [[Int]],
        upsampleKernelSizes: [Int],
        genIstftNFft: Int,
        genIstftHopSize: Int
    ) {
        numKernels = resblockKernelSizes.count
        numUpsamples = upsampleRates.count

        let upsampleScaleNum: MLXArray = MLX.product(MLXArray(upsampleRates)) * genIstftHopSize
        let upsampleScaleNumVal: Int = upsampleScaleNum.item()

        mSource = SourceModuleHnNSF(
            weights: weights,
            samplingRate: KokoroTTS.Constants.samplingRate,
            upsampleScale: upsampleScaleNum.item(),
            harmonicNum: 8,
            voicedThreshold: 10
        )

        f0Upsample = Upsample(scaleFactor: .float(Float(upsampleScaleNumVal)))

        noiseConvs = []
        noiseRes = []
        ups = []
        resBlocks = []
        postNFFt = genIstftNFft

        convPost = ConvWeighted(
            weightG: weights["decoder.generator.conv_post.weight_g"]!,
            weightV: weights["decoder.generator.conv_post.weight_v"]!,
            bias: weights["decoder.generator.conv_post.bias"]!,
            stride: 1,
            padding: 3
        )

        reflectionPad = ReflectionPad1d(padding: (1, 0))

        stft = MLXSTFT(
            filterLength: genIstftNFft,
            hopLength: genIstftHopSize,
            winLength: genIstftNFft
        )

        initializeUpsampling(weights: weights, upsampleRates: upsampleRates, upsampleKernelSizes: upsampleKernelSizes)
        initializeResBlocksAndNoise(
            weights: weights,
            styleDim: styleDim,
            resblockKernelSizes: resblockKernelSizes,
            resblockDilationSizes: resblockDilationSizes,
            upsampleRates: upsampleRates,
            upsampleInitialChannel: upsampleInitialChannel,
            genIstftNFft: genIstftNFft
        )
    }

    func callAsFunction(_ x: MLXArray, _ s: MLXArray, _ f0Curve: MLXArray) -> MLXArray {
        var f0New: MLXArray = f0Curve[.newAxis, 0..., 0...].transposed(0, 2, 1)
        f0New = f0Upsample(f0New)

        let sourceOutput: SourceModuleOutput = mSource(f0New)
        var harSource: MLXArray = sourceOutput.sineMerge

        harSource = MLX.squeezed(harSource.transposed(0, 2, 1), axis: 1)
        let (harSpec, harPhase): (MLXArray, MLXArray) = stft.transform(inputData: harSource)

        var har: MLXArray = MLX.concatenated([harSpec, harPhase], axis: 1)
        har = MLX.swappedAxes(har, 2, 1)

        var tensor: MLXArray = x
        for layerIndex in 0 ..< numUpsamples {
            tensor = LeakyReLU(negativeSlope: 0.1)(tensor)
            var sourceData: MLXArray = noiseConvs[layerIndex](har)
            sourceData = MLX.swappedAxes(sourceData, 2, 1)
            sourceData = noiseRes[layerIndex](sourceData, s)

            tensor = MLX.swappedAxes(tensor, 2, 1)
            tensor = ups[layerIndex](tensor, conv: MLX.convTransposed1d)
            tensor = MLX.swappedAxes(tensor, 2, 1)

            if layerIndex == numUpsamples - 1 {
                tensor = reflectionPad(tensor)
            }
            tensor += sourceData

            var aggregatedOutput: MLXArray?
            for kernelIndex in 0 ..< numKernels {
                if aggregatedOutput == nil {
                    aggregatedOutput = resBlocks[layerIndex * numKernels + kernelIndex](tensor, s)
                } else {
                    let temp: MLXArray = resBlocks[layerIndex * numKernels + kernelIndex](tensor, s)
                    aggregatedOutput = aggregatedOutput! + temp
                }
            }
            tensor = aggregatedOutput! / numKernels
        }

        tensor = LeakyReLU(negativeSlope: 0.01)(tensor)

        tensor = MLX.swappedAxes(tensor, 2, 1)
        tensor = convPost(tensor, conv: MLX.conv1d)
        tensor = MLX.swappedAxes(tensor, 2, 1)

        let spec: MLXArray = MLX.exp(tensor[0..., 0 ..< (postNFFt / 2 + 1), 0...])
        let phase: MLXArray = MLX.sin(tensor[0..., (postNFFt / 2 + 1)..., 0...])

        return stft.inverse(magnitude: spec, phase: phase) as MLXArray
    }

    private func initializeUpsampling(weights: [String: MLXArray], upsampleRates: [Int], upsampleKernelSizes: [Int]) {
        for (layerIndex, (upsampleRate, kernelSize)) in zip(upsampleRates, upsampleKernelSizes).enumerated() {
            ups.append(
                ConvWeighted(
                    weightG: weights["decoder.generator.ups.\(layerIndex).weight_g"]!,
                    weightV: weights["decoder.generator.ups.\(layerIndex).weight_v"]!,
                    bias: weights["decoder.generator.ups.\(layerIndex).bias"]!,
                    stride: upsampleRate,
                    padding: (kernelSize - upsampleRate) / 2
                )
            )
        }
    }

    private func initializeResBlocksAndNoise(
        weights: [String: MLXArray],
        styleDim: Int,
        resblockKernelSizes: [Int],
        resblockDilationSizes: [[Int]],
        upsampleRates: [Int],
        upsampleInitialChannel: Int,
        genIstftNFft: Int
    ) {
        for layerIndex in 0 ..< ups.count {
            let channelCount: Int = upsampleInitialChannel / Int(pow(2.0, Double(layerIndex + 1)))
            for (kernelIndex, (kernelSize, dilationSizes)) in zip(resblockKernelSizes, resblockDilationSizes).enumerated() {
                resBlocks.append(
                    AdaINResBlock1(
                        weights: weights,
                        weightPrefixKey: "decoder.generator.resblocks.\((layerIndex * resblockKernelSizes.count) + kernelIndex)",
                        channels: channelCount,
                        kernelSize: kernelSize,
                        dilation: dilationSizes,
                        styleDim: styleDim
                    )
                )
            }

            initializeNoiseComponents(
                weights: weights,
                styleDim: styleDim,
                genIstftNFft: genIstftNFft,
                channelIndex: layerIndex,
                channelCount: channelCount,
                upsampleRates: upsampleRates
            )
        }
    }

    private func initializeNoiseComponents(
        weights: [String: MLXArray],
        styleDim: Int,
        genIstftNFft: Int,
        channelIndex: Int,
        channelCount: Int,
        upsampleRates: [Int]
    ) {
        if channelIndex + 1 < upsampleRates.count {
            let strideF0: Int = MLX.product(MLXArray(upsampleRates)[(channelIndex + 1)...]).item()
            noiseConvs.append(
                Conv1dInference(
                    inputChannels: genIstftNFft + 2,
                    outputChannels: channelCount,
                    kernelSize: strideF0 * 2,
                    stride: strideF0,
                    padding: (strideF0 + 1) / 2,
                    weight: weights["decoder.generator.noise_convs.\(channelIndex).weight"]!,
                    bias: weights["decoder.generator.noise_convs.\(channelIndex).bias"]!
                )
            )
            noiseRes.append(
                AdaINResBlock1(
                    weights: weights,
                    weightPrefixKey: "decoder.generator.noise_res.\(channelIndex)",
                    channels: channelCount,
                    kernelSize: 7,
                    dilation: [1, 3, 5],
                    styleDim: styleDim
                )
            )
        } else {
            noiseConvs.append(
                Conv1dInference(
                    inputChannels: genIstftNFft + 2,
                    outputChannels: channelCount,
                    kernelSize: 1,
                    weight: weights["decoder.generator.noise_convs.\(channelIndex).weight"]!,
                    bias: weights["decoder.generator.noise_convs.\(channelIndex).bias"]!
                )
            )
            noiseRes.append(
                AdaINResBlock1(
                    weights: weights,
                    weightPrefixKey: "decoder.generator.noise_res.\(channelIndex)",
                    channels: channelCount,
                    kernelSize: 11,
                    dilation: [1, 3, 5],
                    styleDim: styleDim
                )
            )
        }
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
// swiftlint:enable force_unwrapping
