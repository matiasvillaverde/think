import Foundation
import MLX
import MLXFast
import MLXNN

internal struct Mamba2Configuration: Decodable, Sendable {
    let modelType: String
    let vocabularySize: Int
    let hiddenSize: Int
    let hiddenLayers: Int
    let numHeads: Int
    let headDim: Int
    let nGroups: Int
    let convKernel: Int
    let stateSize: Int
    let timeStepRank: Int
    let rmsNormEps: Float
    let useBias: Bool
    let useConvBias: Bool
    let tieWordEmbeddings: Bool
    let timeStepMin: Float
    let timeStepMax: Float
    let timeStepLimit: (Float, Float)

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case vocabularySize = "vocab_size"
        case hiddenSize = "hidden_size"
        case hiddenLayers = "num_hidden_layers"
        case numHeads = "num_heads"
        case headDim = "head_dim"
        case nGroups = "n_groups"
        case convKernel = "conv_kernel"
        case stateSize = "state_size"
        case timeStepRank = "time_step_rank"
        case rmsNormEps = "layer_norm_epsilon"
        case useBias = "use_bias"
        case useConvBias = "use_conv_bias"
        case tieWordEmbeddings = "tie_word_embeddings"
        case timeStepMin = "time_step_min"
        case timeStepMax = "time_step_max"
        case timeStepLimit = "time_step_limit"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        modelType = try container.decodeIfPresent(String.self, forKey: .modelType) ?? "mamba2"
        vocabularySize = try container.decodeIfPresent(Int.self, forKey: .vocabularySize) ?? 50288
        hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        hiddenLayers = try container.decode(Int.self, forKey: .hiddenLayers)
        numHeads = try container.decode(Int.self, forKey: .numHeads)
        headDim = try container.decode(Int.self, forKey: .headDim)
        nGroups = try container.decodeIfPresent(Int.self, forKey: .nGroups) ?? 1
        convKernel = try container.decodeIfPresent(Int.self, forKey: .convKernel) ?? 4
        stateSize = try container.decodeIfPresent(Int.self, forKey: .stateSize) ?? 128
        timeStepRank = try container.decodeIfPresent(Int.self, forKey: .timeStepRank) ?? 256
        rmsNormEps = try container.decodeIfPresent(Float.self, forKey: .rmsNormEps) ?? 1.0e-5
        useBias = try container.decodeIfPresent(Bool.self, forKey: .useBias) ?? false
        useConvBias = try container.decodeIfPresent(Bool.self, forKey: .useConvBias) ?? true
        tieWordEmbeddings = try container.decodeIfPresent(Bool.self, forKey: .tieWordEmbeddings) ?? true
        timeStepMin = try container.decodeIfPresent(Float.self, forKey: .timeStepMin) ?? 0.001
        timeStepMax = try container.decodeIfPresent(Float.self, forKey: .timeStepMax) ?? 0.1

        if let limit = try container.decodeIfPresent([Float].self, forKey: .timeStepLimit),
            limit.count == 2
        {
            timeStepLimit = (limit[0], limit[1])
        } else {
            timeStepLimit = (timeStepMin, timeStepMax)
        }
    }
}

private final class Mamba2RMSNormGated: Module {
    @ParameterInfo(key: "weight") var weight: MLXArray
    let eps: Float

    init(dimensions: Int, eps: Float) {
        self.eps = eps
        self._weight.wrappedValue = MLXArray.ones([dimensions])
        super.init()
    }

    func callAsFunction(_ hiddenStates: MLXArray, gate: MLXArray?) -> MLXArray {
        var states = hiddenStates
        if let gate {
            states = states * silu(gate)
        }
        return MLXFast.rmsNorm(states, weight: weight, eps: eps)
    }
}

private final class Mamba2Mixer: Module {
    let numHeads: Int
    let hiddenSize: Int
    let ssmStateSize: Int
    let convKernelSize: Int
    let intermediateSize: Int
    let numGroups: Int
    let headDim: Int
    let timeStepLimit: (Float, Float)

    let convDim: Int

    @ModuleInfo(key: "conv1d") var conv1d: Conv1d
    @ModuleInfo(key: "in_proj") var inProj: Linear
    @ModuleInfo(key: "out_proj") var outProj: Linear

    @ParameterInfo(key: "dt_bias") var dtBias: MLXArray
    @ParameterInfo(key: "A_log") var aLog: MLXArray
    @ParameterInfo(key: "D") var d: MLXArray

    @ModuleInfo(key: "norm") var norm: Mamba2RMSNormGated

    init(_ config: Mamba2Configuration) {
        self.numHeads = config.numHeads
        self.hiddenSize = config.hiddenSize
        self.ssmStateSize = config.stateSize
        self.convKernelSize = config.convKernel
        self.numGroups = config.nGroups
        self.headDim = config.headDim
        self.intermediateSize = numHeads * headDim
        self.timeStepLimit = config.timeStepLimit
        self.convDim = intermediateSize + 2 * numGroups * ssmStateSize

        _conv1d.wrappedValue = Conv1d(
            inputChannels: convDim,
            outputChannels: convDim,
            kernelSize: convKernelSize,
            groups: convDim,
            bias: config.useConvBias
        )

        let projectionSize = intermediateSize + convDim + numHeads
        _inProj.wrappedValue = Linear(
            hiddenSize, projectionSize, bias: config.useBias)

        _dtBias.wrappedValue = MLXArray.ones([numHeads])
        let headsRange = (MLXArray(0 ..< numHeads).asType(.float32) + 1)
        _aLog.wrappedValue = MLX.log(headsRange)
        _d.wrappedValue = MLXArray.ones([numHeads])

        _norm.wrappedValue = Mamba2RMSNormGated(
            dimensions: intermediateSize, eps: config.rmsNormEps)
        _outProj.wrappedValue = Linear(
            intermediateSize, hiddenSize, bias: config.useBias)
    }

    private func applyConv(_ input: MLXArray, cache: MambaCache?) -> MLXArray {
        let batch = input.dim(0)
        let dtype = input.dtype
        var convState = cache?[0]

        if convState == nil {
            if convKernelSize > 1 {
                convState = MLXArray.zeros([batch, convKernelSize - 1, convDim], dtype: dtype)
            } else {
                convState = MLXArray.zeros([batch, 0, convDim], dtype: dtype)
            }
        }

        let padded = concatenated([convState!, input], axis: 1)

        if let cache {
            let end = padded.dim(1)
            let start = max(0, end - (convKernelSize - 1))
            cache[0] = padded[0..., start ..< end, 0...]
        }

        let convOutput = conv1d(padded)
        return silu(convOutput)
    }

    func callAsFunction(
        _ hiddenStates: MLXArray,
        mask: MLXArray? = nil,
        cache: MambaCache?
    ) -> MLXArray {
        let projected = inProj(hiddenStates)
        let splits = split(
            projected, indices: [intermediateSize, intermediateSize + convDim], axis: -1)
        let gate = splits[0]
        var convInput = splits[1]
        let dt = splits[2]

        if let mask {
            let expandedMask = expandedDimensions(mask, axis: -1)
            convInput = MLX.where(expandedMask, convInput, MLXArray.zeros(like: convInput))
        }

        let convOutput = applyConv(convInput, cache: cache)
        let convSplits = split(
            convOutput,
            indices: [intermediateSize, intermediateSize + numGroups * ssmStateSize],
            axis: -1
        )

        var hidden = convSplits[0]
        var B = convSplits[1]
        var C = convSplits[2]

        hidden = hidden.reshaped([hidden.dim(0), hidden.dim(1), numHeads, headDim])
        B = B.reshaped([B.dim(0), B.dim(1), numGroups, ssmStateSize])
        C = C.reshaped([C.dim(0), C.dim(1), numGroups, ssmStateSize])

        let dtArray = dt.reshaped([dt.dim(0), dt.dim(1), numHeads])

        let previousState = cache?[1]
        let (y, nextState) = ssmUpdate(
            hiddenStates: hidden,
            ALog: aLog,
            B: B,
            C: C,
            D: d,
            dt: dtArray,
            dtBias: dtBias,
            state: previousState,
            timeStepLimit: timeStepLimit,
            mask: mask
        )

        if let cache {
            cache[1] = nextState
        }

        let flattenedY = y.flattened(start: 2)
        return outProj(norm(flattenedY, gate: gate))
    }
}

private final class Mamba2Block: Module {
    @ModuleInfo(key: "mixer") var mixer: Mamba2Mixer
    @ModuleInfo(key: "norm") var norm: RMSNorm

    init(_ config: Mamba2Configuration) {
        _mixer.wrappedValue = Mamba2Mixer(config)
        _norm.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
    }

    func callAsFunction(_ x: MLXArray, cache: MambaCache?) -> MLXArray {
        let residual = x
        let h = mixer(norm(x), cache: cache)
        return residual + h
    }
}

private final class Mamba2Backbone: Module {
    @ModuleInfo(key: "embeddings") var embeddings: Embedding
    @ModuleInfo(key: "norm_f") var normF: RMSNorm
    let layers: [Mamba2Block]

    init(_ config: Mamba2Configuration) {
        _embeddings.wrappedValue = Embedding(
            embeddingCount: config.vocabularySize,
            dimensions: config.hiddenSize
        )
        _normF.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
        self.layers = (0 ..< config.hiddenLayers).map { _ in Mamba2Block(config) }
        super.init()
    }

    func callAsFunction(_ inputs: MLXArray, cache: [MambaCache?]?) -> MLXArray {
        var h = embeddings(inputs)
        let cache = cache ?? Array(repeating: nil as MambaCache?, count: layers.count)
        for (layer, layerCache) in zip(layers, cache) {
            h = layer(h, cache: layerCache)
        }
        return normF(h)
    }
}

internal final class Mamba2Model: Module, LLMModel {
    @ModuleInfo(key: "backbone") private var backbone: Mamba2Backbone
    @ModuleInfo(key: "lm_head") var lmHead: Linear

    let config: Mamba2Configuration
    var vocabularySize: Int { config.vocabularySize }

    init(_ config: Mamba2Configuration) {
        self.config = config
        self._backbone.wrappedValue = Mamba2Backbone(config)
        self._lmHead.wrappedValue = Linear(config.hiddenSize, config.vocabularySize, bias: false)
        super.init()
    }

    func callAsFunction(_ inputs: MLXArray, cache: [KVCache]? = nil) -> MLXArray {
        let out = backbone(inputs, cache: cache as? [MambaCache?])
        return lmHead(out)
    }

    func newCache(parameters: GenerateParameters? = nil) -> [KVCache] {
        (0 ..< config.hiddenLayers).map { _ in MambaCache() }
    }

    func sanitize(weights: [String: MLXArray]) -> [String: MLXArray] {
        var processed = weights

        if processed["lm_head.weight"] == nil,
            let embedWeight = processed["backbone.embeddings.weight"]
        {
            processed["lm_head.weight"] = embedWeight
        }

        var sanitized = [String: MLXArray]()
        for (name, param) in processed {
            var updated = param
            if name.hasSuffix("conv1d.weight"),
                param.shape.count == 3,
                param.shape.last ?? 0 > param.shape[1]
            {
                updated = param.transposed(0, 2, 1)
            }
            sanitized[name] = updated
        }

        return sanitized
    }
}

extension Mamba2Model: LoRAModel {
    public func loraLinearLayers() -> LoRALinearLayers {
        []
    }
}
