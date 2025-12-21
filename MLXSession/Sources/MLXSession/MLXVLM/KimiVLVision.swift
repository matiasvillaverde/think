import Foundation
import MLX
import MLXNN

private func rotateHalf(_ x: MLXArray) -> MLXArray {
    let splitPoint = x.dim(-1) / 2
    let x1 = x[.ellipsis, 0 ..< splitPoint]
    let x2 = x[.ellipsis, splitPoint...]
    return concatenated([-x2, x1], axis: -1)
}

private func applyRotary(_ tensor: MLXArray, freqs: MLXArray) -> MLXArray {
    var cosValues = cos(freqs)
    var sinValues = sin(freqs)

    cosValues = expandedDimensions(cosValues, axis: 1)
    cosValues = tiled(cosValues, repetitions: [1, 1, 2])
    cosValues = expandedDimensions(cosValues, axis: 0)

    sinValues = expandedDimensions(sinValues, axis: 1)
    sinValues = tiled(sinValues, repetitions: [1, 1, 2])
    sinValues = expandedDimensions(sinValues, axis: 0)

    let output = (tensor * cosValues) + (rotateHalf(tensor) * sinValues)
    return output.asType(tensor.dtype)
}

final class Learnable2DInterpPosEmb: Module {
    let height: Int
    let width: Int
    let dim: Int

    @ModuleInfo(key: "weight") var weight: MLXArray

    init(height: Int, width: Int, dim: Int) {
        self.height = height
        self.width = width
        self.dim = dim
        self._weight.wrappedValue = MLXArray.ones([height, width, dim])
    }

    func callAsFunction(_ x: MLXArray, gridHws: MLXArray) -> MLXArray {
        var positionEmbeddings = [MLXArray]()
        let shapes = gridHws.asArray(Int.self)
        for index in stride(from: 0, to: shapes.count, by: 2) {
            let h = shapes[index]
            let w = shapes[index + 1]
            if h == height && w == width {
                positionEmbeddings.append(weight.reshaped(-1, dim))
            } else {
                let resized = interpolate(
                    expandedDimensions(weight.transposed(2, 0, 1), axis: 0),
                    size: (h, w),
                    mode: .bicubic,
                    alignCorners: false
                )
                let flattened = resized.squeezed(axis: 0).transposed(1, 2, 0).reshaped(-1, dim)
                positionEmbeddings.append(flattened)
            }
        }
        let posEmbeds = concatenated(positionEmbeddings, axis: 0).asType(x.dtype)
        return x + posEmbeds
    }
}

internal final class PatchEmbed: Module {
    let patchSize: Int
    @ModuleInfo(key: "proj") var proj: Conv2d
    @ModuleInfo(key: "pos_emb") private var posEmb: Learnable2DInterpPosEmb

    init(
        patchSize: Int,
        numChannels: Int,
        embedDim: Int,
        initPosEmbHeight: Int,
        initPosEmbWidth: Int
    ) {
        self.patchSize = patchSize
        let kernel = IntOrPair([patchSize, patchSize])
        self._proj.wrappedValue = Conv2d(
            inputChannels: numChannels,
            outputChannels: embedDim,
            kernelSize: kernel,
            stride: kernel,
            bias: true
        )
        self._posEmb.wrappedValue = Learnable2DInterpPosEmb(
            height: initPosEmbHeight,
            width: initPosEmbWidth,
            dim: embedDim
        )
    }

    func callAsFunction(_ hiddenStates: MLXArray, gridHws: MLXArray) -> MLXArray {
        var hiddenStates = proj(hiddenStates).swappedAxes(1, 3)
        hiddenStates = hiddenStates.reshaped(hiddenStates.dim(0), -1)
        hiddenStates = posEmb(hiddenStates, gridHws: gridHws)
        return hiddenStates
    }
}

private final class Attention: Module {
    let numHeads: Int
    let headDim: Int
    @ModuleInfo(key: "wqkv") var wqkv: Linear
    @ModuleInfo(key: "wo") var wo: Linear

    init(dim: Int, numHeads: Int) {
        self.numHeads = numHeads
        self.headDim = dim / numHeads
        self._wqkv.wrappedValue = Linear(dim, dim * 3, bias: true)
        self._wo.wrappedValue = Linear(dim, dim, bias: true)
    }

    func callAsFunction(_ x: MLXArray, cuSeqlens: MLXArray, rotaryPosEmb: MLXArray) -> MLXArray {
        let sequenceLength = x.dim(0)
        let qkv = wqkv(x)
        let reshaped = qkv.reshaped(sequenceLength, 3, numHeads, headDim)
        let parts = split(reshaped, parts: 3, axis: 1)
        var q = parts[0].squeezed(axis: 1)
        var k = parts[1].squeezed(axis: 1)
        var v = parts[2].squeezed(axis: 1)

        q = applyRotary(q, freqs: rotaryPosEmb)
        k = applyRotary(k, freqs: rotaryPosEmb)

        q = q.transposed(1, 0, 2)
        k = k.transposed(1, 0, 2)
        v = v.transposed(1, 0, 2)

        var attnWeights = matmul(q, k.swappedAxes(-1, -2)) / sqrt(Float(headDim))

        if cuSeqlens.size > 1 {
            var mask = MLXArray.ones([1, sequenceLength, sequenceLength]) * MLXArray(-1.0e9)
            let boundaries = cuSeqlens.asArray(Int.self)
            for index in 1 ..< boundaries.count {
                let start = boundaries[index - 1]
                let end = boundaries[index]
                mask[0..., start ..< end, start ..< end] = MLXArray(0.0)
            }
            attnWeights = attnWeights + mask
        }

        attnWeights = softmax(attnWeights, axis: -1).asType(q.dtype)
        var attnOutput = matmul(attnWeights, v)
        attnOutput = attnOutput.transposed(1, 0, 2).reshaped(sequenceLength, -1)
        return wo(attnOutput)
    }
}

private final class MLP: Module {
    @ModuleInfo var activation: GELU
    @ModuleInfo var fc0: Linear
    @ModuleInfo var fc1: Linear

    init(dim: Int, hiddenDim: Int) {
        self.activation = GELU()
        self.fc0 = Linear(dim, hiddenDim)
        self.fc1 = Linear(hiddenDim, dim)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        fc1(activation(fc0(x)))
    }
}

private final class Qwen2VLVisionBlock: Module {
    @ModuleInfo(key: "norm0") var norm0: LayerNorm
    @ModuleInfo(key: "norm1") var norm1: LayerNorm
    @ModuleInfo(key: "attn") var attn: Attention
    @ModuleInfo(key: "mlp") var mlp: MLP

    init(config: KimiVLVisionConfiguration) {
        self._norm0.wrappedValue = LayerNorm(dimensions: config.embedDim, eps: config.layerNormEps)
        self._norm1.wrappedValue = LayerNorm(dimensions: config.embedDim, eps: config.layerNormEps)
        self._attn.wrappedValue = Attention(dim: config.embedDim, numHeads: config.numHeads)
        self._mlp.wrappedValue = MLP(dim: config.embedDim, hiddenDim: config.intermediateSize)
    }

    func callAsFunction(
        _ hiddenStates: MLXArray,
        cuSeqlens: MLXArray,
        rotaryPosEmb: MLXArray
    ) -> MLXArray {
        var hiddenStates = hiddenStates + attn(norm0(hiddenStates), cuSeqlens: cuSeqlens, rotaryPosEmb: rotaryPosEmb)
        hiddenStates = hiddenStates + mlp(norm1(hiddenStates))
        return hiddenStates
    }
}

private final class Rope2DPosEmb {
    let dim: Int
    let maxHeight: Int
    let maxWidth: Int
    let thetaBase: Float
    private var freqs: MLXArray?

    init(dim: Int, maxHeight: Int, maxWidth: Int, thetaBase: Float = 10_000) {
        self.dim = dim
        self.maxHeight = maxHeight
        self.maxWidth = maxWidth
        self.thetaBase = thetaBase
    }

    private func precompute() -> MLXArray {
        let total = maxHeight * maxWidth
        let flatPos = MLXArray(0 ..< total).asType(.float32)
        let xPos = flatPos % MLXArray(Float(maxWidth))
        let yPos = flatPos / MLXArray(Float(maxWidth))
        let dimRange = MLXArray(stride(from: 0, to: dim, by: 4)).asType(.float32)
        let freqs = 1.0 / pow(thetaBase, dimRange / Float(dim))
        let xFreqs = outer(xPos, freqs)
        let yFreqs = outer(yPos, freqs)

        let xStack = stacked([xFreqs, yFreqs], axis: -1)
        let merged = xStack.reshaped(total, dim / 2)
        return merged.reshaped(maxHeight, maxWidth, dim / 2)
    }

    func getFreqs(gridHws: MLXArray) -> MLXArray {
        if freqs == nil {
            freqs = precompute()
        }

        guard let freqs else {
            return MLXArray([])
        }

        let shapes = gridHws.asArray(Int.self)
        var collected = [MLXArray]()
        for index in stride(from: 0, to: shapes.count, by: 2) {
            let h = shapes[index]
            let w = shapes[index + 1]
            let slice = freqs[0 ..< h, 0 ..< w]
            collected.append(slice.reshaped(-1, dim / 2))
        }

        return concatenated(collected, axis: 0)
    }
}

private func patchMerger(
    _ x: MLXArray,
    gridHws: MLXArray,
    mergeKernelSize: [Int]
) -> [MLXArray] {
    let dModel = x.dim(-1)
    let shapes = gridHws.asArray(Int.self)
    var outputs: [MLXArray] = []
    var offset = 0

    for index in stride(from: 0, to: shapes.count, by: 2) {
        let height = shapes[index]
        let width = shapes[index + 1]
        let length = height * width
        let seq = x[offset ..< offset + length]
        let kernelHeight = mergeKernelSize[0]
        let kernelWidth = mergeKernelSize[1]
        let newHeight = height / kernelHeight
        let newWidth = width / kernelWidth
        var reshaped = seq.reshaped(
            newHeight, kernelHeight, newWidth, kernelWidth, dModel
        )
        reshaped = reshaped.transposed(0, 2, 1, 3, 4)
        let padded = reshaped.reshaped(
            newHeight * newWidth, kernelHeight * kernelWidth, dModel
        )
        outputs.append(padded)
        offset += length
    }

    return outputs
}

internal final class KimiVLVisionModel: Module {
    @ModuleInfo(key: "patch_embed") var patchEmbed: PatchEmbed
    @ModuleInfo(key: "final_layernorm") var finalLayerNorm: LayerNorm

    let mergeKernelSize: [Int]
    @ModuleInfo(key: "blocks") private var blocks: [Qwen2VLVisionBlock]
    private let ropePosEmb: Rope2DPosEmb

    init(_ config: KimiVLVisionConfiguration) {
        self.mergeKernelSize = config.mergeKernelSize
        self._patchEmbed.wrappedValue = PatchEmbed(
            patchSize: config.patchSize,
            numChannels: config.numChannels,
            embedDim: config.embedDim,
            initPosEmbHeight: config.initPosEmbHeight,
            initPosEmbWidth: config.initPosEmbWidth
        )
        self._blocks.wrappedValue = (0 ..< config.depth).map { _ in
            Qwen2VLVisionBlock(config: config)
        }
        self._finalLayerNorm.wrappedValue = LayerNorm(dimensions: config.hiddenSize, eps: 1e-6)

        let headDim = config.embedDim / config.numHeads
        self.ropePosEmb = Rope2DPosEmb(dim: headDim, maxHeight: 512, maxWidth: 512)
    }

    func callAsFunction(
        _ hiddenStates: MLXArray,
        gridHws: MLXArray,
        outputHiddenStates: Bool = false
    ) -> [MLXArray] {
        var hiddenStates = patchEmbed(hiddenStates, gridHws: gridHws)
        let rotaryPosEmb = ropePosEmb.getFreqs(gridHws: gridHws)

        let lengths = concatenated([
            zeros([1]).asType(gridHws.dtype),
            gridHws[.ellipsis, 0] * gridHws[.ellipsis, 1]
        ])
        let cuSeqlens = cumsum(lengths.asType(.int32), axis: 0)

        var encoderStates: [MLXArray] = outputHiddenStates ? [hiddenStates] : []
        for block in blocks {
            hiddenStates = block(
                hiddenStates,
                cuSeqlens: cuSeqlens,
                rotaryPosEmb: rotaryPosEmb
            )
            if outputHiddenStates {
                encoderStates.append(hiddenStates)
            }
        }

        hiddenStates = finalLayerNorm(hiddenStates)
        return patchMerger(hiddenStates, gridHws: gridHws, mergeKernelSize: mergeKernelSize)
    }

    func sanitize(weights: [String: MLXArray]) -> [String: MLXArray] {
        func isMLXWeight(_ array: MLXArray) -> Bool {
            if array.ndim != 4 {
                return false
            }
            let (outChannels, kH, kW, _) = (array.dim(0), array.dim(1), array.dim(2), array.dim(3))
            return outChannels >= kH && outChannels >= kW && kH == kW
        }

        var sanitized: [String: MLXArray] = [:]

        for (key, value) in weights {
            if key.contains("position_ids") {
                continue
            }
            if key.contains("patch_embed.proj.weight") {
                sanitized[key] = isMLXWeight(value) ? value : value.transposed(0, 2, 3, 1)
                continue
            }
            if key.contains("vision_tower.blocks"),
               !key.contains("attn"),
               (key.contains("wqkv") || key.contains("wo")) {
                let newKey = key.replacingOccurrences(of: "wqkv", with: "attn.wqkv")
                    .replacingOccurrences(of: "wo", with: "attn.wo")
                sanitized[newKey] = value
                continue
            }
            sanitized[key] = value
        }
        return sanitized
    }
}
