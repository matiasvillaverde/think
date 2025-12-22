import Foundation
import MLX
import MLXNN

internal struct MambaConfiguration: Decodable, Sendable {
    let modelType: String
    let vocabularySize: Int
    let hiddenSize: Int
    let hiddenLayers: Int
    let intermediateSize: Int
    let convKernel: Int
    let stateSize: Int
    let timeStepRank: Int
    let rmsNormEps: Float
    let useBias: Bool
    let useConvBias: Bool
    let tieWordEmbeddings: Bool
    let timeStepMin: Float
    let timeStepMax: Float
    let timeStepFloor: Float

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case vocabularySize = "vocab_size"
        case hiddenSize = "d_model"
        case hiddenLayers = "n_layer"
        case intermediateSize = "d_inner"
        case convKernel = "conv_kernel"
        case stateSize = "state_size"
        case timeStepRank = "time_step_rank"
        case rmsNormEps = "layer_norm_epsilon"
        case useBias = "use_bias"
        case useConvBias = "use_conv_bias"
        case tieWordEmbeddings = "tie_word_embeddings"
        case expand
        case timeStepMin = "time_step_min"
        case timeStepMax = "time_step_max"
        case timeStepFloor = "time_step_floor"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        modelType = try container.decodeIfPresent(String.self, forKey: .modelType) ?? "mamba"
        vocabularySize = try container.decode(Int.self, forKey: .vocabularySize)
        hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        hiddenLayers = try container.decode(Int.self, forKey: .hiddenLayers)
        let dInner = try container.decodeIfPresent(Int.self, forKey: .intermediateSize)
        let expand = try container.decodeIfPresent(Int.self, forKey: .expand)
        intermediateSize = dInner ?? (expand ?? 2) * hiddenSize
        convKernel = try container.decodeIfPresent(Int.self, forKey: .convKernel) ?? 4
        stateSize = try container.decodeIfPresent(Int.self, forKey: .stateSize) ?? 16
        timeStepRank = try container.decodeIfPresent(Int.self, forKey: .timeStepRank) ?? 48
        rmsNormEps = try container.decodeIfPresent(Float.self, forKey: .rmsNormEps) ?? 1.0e-5
        useBias = try container.decodeIfPresent(Bool.self, forKey: .useBias) ?? false
        useConvBias = try container.decodeIfPresent(Bool.self, forKey: .useConvBias) ?? true
        tieWordEmbeddings = try container.decodeIfPresent(Bool.self, forKey: .tieWordEmbeddings) ?? true
        timeStepMin = try container.decodeIfPresent(Float.self, forKey: .timeStepMin) ?? 0.001
        timeStepMax = try container.decodeIfPresent(Float.self, forKey: .timeStepMax) ?? 0.1
        timeStepFloor = try container.decodeIfPresent(Float.self, forKey: .timeStepFloor) ?? 0.0001
    }
}

private final class MambaMixer: Module {
    let hiddenSize: Int
    let ssmStateSize: Int
    let convKernelSize: Int
    let intermediateSize: Int
    let timeStepRank: Int
    let useConvBias: Bool
    let useBias: Bool
    let timeStepLimit: (Float, Float)
    let timeStepFloor: Float

    @ModuleInfo(key: "in_proj") var inProj: Linear
    @ModuleInfo(key: "conv1d") var conv1d: Conv1d
    @ModuleInfo(key: "x_proj") var xProj: Linear
    @ModuleInfo(key: "dt_proj") var dtProj: Linear

    @ParameterInfo(key: "A_log") var aLog: MLXArray
    @ParameterInfo(key: "D") var d: MLXArray

    @ModuleInfo(key: "out_proj") var outProj: Linear

    init(_ config: MambaConfiguration) {
        self.hiddenSize = config.hiddenSize
        self.ssmStateSize = config.stateSize
        self.convKernelSize = config.convKernel
        self.intermediateSize = config.intermediateSize
        self.timeStepRank = config.timeStepRank
        self.useConvBias = config.useConvBias
        self.useBias = config.useBias
        self.timeStepLimit = (config.timeStepMin, config.timeStepMax)
        self.timeStepFloor = config.timeStepFloor

        _inProj.wrappedValue = Linear(
            hiddenSize, intermediateSize * 2, bias: useBias)

        _conv1d.wrappedValue = Conv1d(
            inputChannels: intermediateSize,
            outputChannels: intermediateSize,
            kernelSize: convKernelSize,
            padding: 0,
            groups: intermediateSize,
            bias: useConvBias
        )

        _xProj.wrappedValue = Linear(
            intermediateSize,
            timeStepRank + ssmStateSize * 2,
            bias: false
        )

        _dtProj.wrappedValue = Linear(timeStepRank, intermediateSize, bias: true)

        let A = repeated(
            MLXArray(Array(1 ... ssmStateSize).map { Float($0) }).reshaped([
                1, ssmStateSize,
            ]),
            count: intermediateSize,
            axis: 0
        )
        _aLog.wrappedValue = log(A)
        _d.wrappedValue = MLXArray.ones([intermediateSize])

        _outProj.wrappedValue = Linear(intermediateSize, hiddenSize, bias: useBias)
    }

    private func ssmStep(_ x: MLXArray, _ A: MLXArray, state: MLXArray?) -> (MLXArray, MLXArray) {
        let T = x.dim(1)

        let deltaBC = xProj(x)
        let splits = MLX.split(
            deltaBC,
            indices: [timeStepRank, timeStepRank + ssmStateSize],
            axis: -1
        )
        var delta = splits[0]
        let B = splits[1]
        let C = splits[2]

        delta = softplus(dtProj(delta))
        delta = maximum(delta, MLXArray(timeStepFloor))
        delta = MLX.clip(delta, min: timeStepLimit.0, max: timeStepLimit.1)

        let newState = expandedDimensions(delta * x, axis: -1) * expandedDimensions(B, axis: -2)
        let dtA = exp(expandedDimensions(delta, axis: -1) * A)

        var currentState = state
        for t in 0 ..< T {
            if let state = currentState {
                newState[0..., t] = state * dtA[0..., t] + newState[0..., t]
            }
            currentState = newState[0..., t]
        }

        let y = (newState.matmul(expandedDimensions(C, axis: -1))).squeezed(axis: -1)
        return (y + d * x, newState[0..., -1])
    }

    private func processSequence(
        _ x: MLXArray,
        convState: MLXArray?,
        ssmState: MLXArray?
    ) -> (MLXArray, (MLXArray, MLXArray)) {
        let xz = inProj(x)
        let splits = xz.split(parts: 2, axis: -1)
        var x = splits[0]
        let z = splits[1]

        let K = convKernelSize
        let xFull: MLXArray
        if let convState = convState {
            xFull = concatenated([convState, x], axis: 1)
        } else {
            xFull = padded(
                x, widths: [IntOrPair((0, 0)), IntOrPair((K - 1, 0)), IntOrPair((0, 0))])
        }

        let convOut = conv1d(xFull)
        let newConvState = xFull[0..., (1 - K)..., 0...]
        x = silu(convOut)

        let A = -exp(aLog)
        let (y, newSsmState) = ssmStep(x, A, state: ssmState)
        let output = outProj(silu(z) * y)

        return (output, (newConvState, newSsmState))
    }

    func callAsFunction(_ x: MLXArray, cache: MambaCache?) -> MLXArray {
        let convState = cache?[0]
        let ssmState = cache?[1]

        let (output, (newConvState, newSsmState)) = processSequence(
            x, convState: convState, ssmState: ssmState)

        if let cache = cache {
            cache[0] = newConvState
            cache[1] = newSsmState
        }

        return output
    }
}

private final class MambaBlock: Module {
    @ModuleInfo(key: "mixer") var mixer: MambaMixer
    @ModuleInfo(key: "norm") var norm: RMSNorm

    init(_ config: MambaConfiguration) {
        _mixer.wrappedValue = MambaMixer(config)
        _norm.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
    }

    func callAsFunction(_ x: MLXArray, cache: MambaCache?) -> MLXArray {
        let residual = x
        let h = mixer(norm(x), cache: cache)
        return residual + h
    }
}

private final class MambaBackbone: Module {
    @ModuleInfo(key: "embeddings") var embeddings: Embedding
    @ModuleInfo(key: "norm_f") var normF: RMSNorm
    let layers: [MambaBlock]

    init(_ config: MambaConfiguration) {
        _embeddings.wrappedValue = Embedding(
            embeddingCount: config.vocabularySize,
            dimensions: config.hiddenSize
        )
        _normF.wrappedValue = RMSNorm(dimensions: config.hiddenSize, eps: config.rmsNormEps)
        self.layers = (0 ..< config.hiddenLayers).map { _ in MambaBlock(config) }
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

internal final class MambaModel: Module, LLMModel {
    @ModuleInfo(key: "backbone") private var backbone: MambaBackbone
    @ModuleInfo(key: "lm_head") var lmHead: Linear

    let config: MambaConfiguration
    var vocabularySize: Int { config.vocabularySize }

    init(_ config: MambaConfiguration) {
        self.config = config
        self._backbone.wrappedValue = MambaBackbone(config)
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

extension MambaModel: LoRAModel {
    public func loraLinearLayers() -> LoRALinearLayers {
        []
    }
}
