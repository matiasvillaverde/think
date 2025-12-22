import Foundation
import MLX
import MLXFast
import MLXNN

internal final class Llama3RoPE: Module, OffsetLayer {
    let dims: Int
    let maxPositionEmbeddings: Int
    let traditional: Bool
    let freqs: MLXArray

    init(
        dims: Int,
        maxPositionEmbeddings: Int = 2048,
        traditional: Bool = false,
        base: Float = 10_000,
        scalingConfig: [String: StringOrNumber]? = nil
    ) {
        self.dims = dims
        self.maxPositionEmbeddings = maxPositionEmbeddings
        self.traditional = traditional

        guard let scalingConfig = scalingConfig else {
            fatalError("Llama3RoPE requires scaling_config")
        }

        let factor = scalingConfig["factor"]?.asFloat() ?? 1.0
        let lowFreqFactor = scalingConfig["low_freq_factor"]?.asFloat() ?? 1.0
        let highFreqFactor = scalingConfig["high_freq_factor"]?.asFloat() ?? 4.0
        let oldContextLen = scalingConfig["original_max_position_embeddings"]?.asFloat() ?? 8192.0

        let lowFreqWavelen = oldContextLen / lowFreqFactor
        let highFreqWavelen = oldContextLen / highFreqFactor

        let indices = MLXArray(stride(from: 0, to: dims, by: 2))
        var frequencies = MLX.pow(base, indices / Float(dims))
        let wavelens = 2 * Float.pi * frequencies

        frequencies = MLX.where(
            wavelens .> MLXArray(lowFreqWavelen),
            frequencies * factor,
            frequencies
        )

        let isMediumFreq = MLX.logicalAnd(
            wavelens .> MLXArray(highFreqWavelen),
            wavelens .< MLXArray(lowFreqWavelen)
        )

        let smoothFactors =
            (oldContextLen / wavelens - lowFreqFactor) / (highFreqFactor - lowFreqFactor)
        let smoothFreqs = frequencies / ((1 - smoothFactors) / factor + smoothFactors)

        self.freqs = MLX.where(isMediumFreq, smoothFreqs, frequencies)
        super.init()
    }

    func callAsFunction(_ x: MLXArray, offset: Int = 0) -> MLXArray {
        MLXFast.RoPE(
            x,
            dimensions: dims,
            traditional: traditional,
            base: nil,
            scale: 1.0,
            offset: offset,
            freqs: freqs
        )
    }
}

internal final class YarnRoPE: Module, OffsetLayer {
    let dimensions: Int
    let traditional: Bool
    let maxPositionEmbeddings: Int
    let base: Float
    let scalingFactor: Float
    let originalMaxPositionEmbeddings: Int
    let betaFast: Float
    let betaSlow: Float
    let mscale: Float
    let mscaleAllDim: Float

    private let _mscale: Float
    private let _freqs: MLXArray

    init(
        dimensions: Int,
        traditional: Bool = false,
        maxPositionEmbeddings: Int = 2048,
        base: Float = 10_000,
        scalingFactor: Float = 1.0,
        originalMaxPositionEmbeddings: Int = 4096,
        betaFast: Float = 32,
        betaSlow: Float = 1,
        mscale: Float = 1,
        mscaleAllDim: Float = 0
    ) {
        precondition(dimensions.isMultiple(of: 2), "Dimensions must be even")

        self.dimensions = dimensions
        self.traditional = traditional
        self.maxPositionEmbeddings = maxPositionEmbeddings
        self.base = base
        self.scalingFactor = scalingFactor
        self.originalMaxPositionEmbeddings = originalMaxPositionEmbeddings
        self.betaFast = betaFast
        self.betaSlow = betaSlow
        self.mscale = mscale
        self.mscaleAllDim = mscaleAllDim

        func yarnFindCorrectionDim(numRotations: Float) -> Float {
            return Float(dimensions)
                * log(Float(originalMaxPositionEmbeddings) / (numRotations * 2 * Float.pi))
                / (2 * log(base))
        }

        func yarnFindCorrectionRange() -> (low: Int, high: Int) {
            let low = Int(floor(yarnFindCorrectionDim(numRotations: betaFast)))
            let high = Int(ceil(yarnFindCorrectionDim(numRotations: betaSlow)))
            return (max(low, 0), min(high, dimensions / 2 - 1))
        }

        func yarnLinearRampMask(minVal: Float, maxVal: Float, dim: Int) -> MLXArray {
            let range = MLXArray(stride(from: 0, to: dim, by: 1)).asType(.float32)
            let mask = (range - minVal) / (maxVal - minVal)
            return MLX.clip(mask, min: 0.0, max: 1.0)
        }

        func yarnGetMscale(scale: Float, mscale: Float) -> Float {
            if scale <= 1 {
                return 1.0
            }
            return 0.1 * mscale * log(scale) + 1.0
        }

        self._mscale = yarnGetMscale(scale: scalingFactor, mscale: mscale)
        let mscaleAllDim = yarnGetMscale(scale: scalingFactor, mscale: mscaleAllDim)

        let freqExtra = pow(
            base,
            MLXArray(stride(from: 0, to: dimensions, by: 2)).asType(.float32)
                / dimensions)
        let freqInter =
            scalingFactor
            * pow(
                base,
                MLXArray(stride(from: 0, to: dimensions, by: 2)).asType(.float32)
                    / dimensions)

        let (low, high) = yarnFindCorrectionRange()
        let freqMask =
            1.0 - yarnLinearRampMask(minVal: Float(low), maxVal: Float(high), dim: dimensions / 2)

        var freqs = (freqInter * freqExtra) / (freqInter * freqMask + freqExtra * (1 - freqMask))

        if mscaleAllDim != 1.0 {
            freqs = freqs * mscaleAllDim
        }

        self._freqs = freqs
    }

    func callAsFunction(_ x: MLXArray, offset: Int = 0) -> MLXArray {
        if _mscale != 1.0 {
            x[.ellipsis, 0 ..< dimensions] = _mscale * x[.ellipsis, 0 ..< dimensions]
        }

        return MLXFast.RoPE(
            x,
            dimensions: dimensions,
            traditional: traditional,
            base: nil,
            scale: 1.0,
            offset: offset,
            freqs: _freqs
        )
    }
}

internal func initializeRope(
    dims: Int,
    base: Float,
    traditional: Bool,
    scalingConfig: [String: StringOrNumber]?,
    maxPositionEmbeddings: Int?
) -> OffsetLayer {
    let ropeType: String = {
        if let config = scalingConfig,
            let typeValue = config["type"] ?? config["rope_type"],
            case .string(let s) = typeValue
        {
            return s
        }
        return "default"
    }()

    if ropeType == "default" || ropeType == "linear" {
        let scale: Float
        if ropeType == "linear", let factor = scalingConfig?["factor"]?.asFloat() {
            scale = 1 / factor
        } else {
            scale = 1.0
        }
        return RoPE(dimensions: dims, traditional: traditional, base: base, scale: scale)
    } else if ropeType == "llama3" {
        return Llama3RoPE(
            dims: dims,
            maxPositionEmbeddings: maxPositionEmbeddings ?? 2048,
            traditional: traditional,
            base: base,
            scalingConfig: scalingConfig
        )
    } else if ropeType == "yarn" {
        let factor = scalingConfig?["factor"]?.asFloat() ?? 32.0
        let origMax = scalingConfig?["original_max_position_embeddings"]?.asInt() ?? 4096
        let betaFast = scalingConfig?["beta_fast"]?.asFloat() ?? 32.0
        let betaSlow = scalingConfig?["beta_slow"]?.asFloat() ?? 1.0
        let mscale = scalingConfig?["mscale"]?.asFloat() ?? 1.0
        let mscaleAllDim = scalingConfig?["mscale_all_dim"]?.asFloat() ?? 0.0

        return YarnRoPE(
            dimensions: dims,
            traditional: traditional,
            maxPositionEmbeddings: maxPositionEmbeddings ?? 2048,
            base: base,
            scalingFactor: factor,
            originalMaxPositionEmbeddings: origMax,
            betaFast: betaFast,
            betaSlow: betaSlow,
            mscale: mscale,
            mscaleAllDim: mscaleAllDim
        )
    } else if ropeType == "longrope" {
        guard let config = scalingConfig else {
            fatalError("longrope requires scaling_config")
        }
        guard let origMax = config["original_max_position_embeddings"]?.asInt() else {
            fatalError("longrope requires original_max_position_embeddings")
        }
        guard let shortFactor = config["short_factor"]?.asFloats() else {
            fatalError("longrope requires short_factor")
        }
        guard let longFactor = config["long_factor"]?.asFloats() else {
            fatalError("longrope requires long_factor")
        }

        return SuScaledRoPE(
            dimensions: dims,
            base: base,
            maxPositionEmbeddings: maxPositionEmbeddings ?? 131072,
            originalMaxPositionEmbeddings: origMax,
            shortFactor: shortFactor,
            longFactor: longFactor
        )
    } else if ropeType == "mrope" {
        fatalError("mrope is not supported in MLXSession")
    }

    fatalError("Unknown rope type \(ropeType)")
}
