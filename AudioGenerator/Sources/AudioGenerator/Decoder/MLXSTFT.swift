import Foundation
import MLX
import MLXFFT
import MLXNN

// Hanning window implementation to replace np.hanning
internal func hanning(length: Int) -> MLXArray {
    if length == 1 {
        return MLXArray(1.0)
    }

    let indexArray: MLXArray = MLXArray(Array(stride(from: Float(1 - length), to: Float(length), by: 2.0)))
    let factor: Float = .pi / Float(length - 1)
    return 0.5 + 0.5 * cos(indexArray * factor)
}

// Unwrap implementation to replace np.unwrap
internal func unwrap(p: MLXArray) -> MLXArray {
    let period: Float = 2.0 * .pi
    let discont: Float = period / 2.0

    let pDiff1: MLXArray = p[0..., 0 ..< p.shape[1] - 1]
    let pDiff2: MLXArray = p[0..., 1 ..< p.shape[1]]

    let pDiff: MLXArray = pDiff2 - pDiff1

    let intervalHigh: Float = period / 2.0
    let intervalLow: Float = -intervalHigh

    var pDiffMod: MLXArray = pDiff - intervalLow
    pDiffMod = (((pDiffMod % period) + period) % period) + intervalLow

    let ddSignArray: MLXArray = MLX.where(pDiff .> 0, intervalHigh, pDiffMod)

    pDiffMod = MLX.where(pDiffMod .== intervalLow, ddSignArray, pDiffMod)

    var phCorrect: MLXArray = pDiffMod - pDiff
    phCorrect = MLX.where(abs(pDiff) .< discont, MLXArray(0.0), phCorrect)

    return MLX.concatenated([p[0..., 0 ..< 1], p[0..., 1...] + phCorrect.cumsum(axis: 1)], axis: 1)
}

internal func mlxStft(
    x: MLXArray,
    nFft: Int = 800,
    hopLength: Int? = nil,
    winLength: Int? = nil,
    window: Any = "hann",
    center: Bool = true,
    padMode: String = "reflect"
) -> MLXArray {
    let hopLen: Int = hopLength ?? nFft / 4
    let winLen: Int = winLength ?? nFft

    var windowData: MLXArray
    if let windowStr = window as? String {
        if windowStr.lowercased() == "hann" {
            windowData = hanning(length: winLen + 1)[0 ..< winLen]
        } else {
            fatalError("Only hanning is supported for window, not \(windowStr)")
        }
    } else if let windowArray = window as? MLXArray {
        windowData = windowArray
    } else {
        fatalError("Window must be a string or MLXArray")
    }

    if windowData.shape[0] < nFft {
        let padSize: Int = nFft - windowData.shape[0]
        windowData = MLX.concatenated([windowData, MLXArray.zeros([padSize])], axis: 0)
    }

    func pad(_ x: MLXArray, padding: Int, padMode: String = "reflect") -> MLXArray {
        if padMode == "constant" {
            return MLX.padded(x, width: [padding, padding])
        }
        if padMode == "reflect" {
            let prefix: MLXArray = x[1 ..< padding + 1][.stride(by: -1)]
            let suffix: MLXArray = x[-(padding + 1) ..< -1][.stride(by: -1)]
            return MLX.concatenated([prefix, x, suffix])
        }
        fatalError("Invalid pad mode \(padMode)")
    }

    var xArray: MLXArray = x

    if center {
        xArray = pad(xArray, padding: nFft / 2, padMode: padMode)
    }

    let numFrames: Int = 1 + (xArray.shape[0] - nFft) / hopLen
    if numFrames <= 0 {
        fatalError("Input is too short")
    }

    let shape: [Int] = [numFrames, nFft]
    let strides: [Int] = [hopLen, 1]

    let frames: MLXArray = MLX.asStrided(xArray, shape, strides: strides)

    let spec: MLXArray = MLXFFT.rfft(frames * windowData)
    return spec.transposed(1, 0)
}

internal func mlxIstft(
    x: MLXArray,
    hopLength: Int? = nil,
    winLength: Int? = nil,
    window: Any = "hann"
) -> MLXArray {
    let winLen: Int = winLength ?? ((x.shape[1] - 1) * 2)
    let hopLen: Int = hopLength ?? (winLen / 4)

    var windowData: MLXArray
    if let windowStr = window as? String {
        if windowStr.lowercased() == "hann" {
            windowData = hanning(length: winLen + 1)[0 ..< winLen]
        } else {
            fatalError("Only hanning window is supported")
        }
    } else if let windowArray = window as? MLXArray {
        windowData = windowArray
    } else {
        fatalError("Window must be a string or MLXArray")
    }

    if windowData.shape[0] < winLen {
        windowData = MLX.concatenated([windowData, MLXArray.zeros([winLen - windowData.shape[0]])], axis: 0)
    }

    let xTransposed: MLXArray = x.transposed(1, 0)
    let totalLength: Int = (xTransposed.shape[0] - 1) * hopLen + winLen
    let windowModLen: Int = 20 / 5

    let wSquared: MLXArray = windowData * windowData
    let totalWsquared: MLXArray = MLX.concatenated(Array(repeating: wSquared, count: totalLength / winLen))

    let output: MLXArray = MLXFFT.irfft(xTransposed, axis: 1) * windowData

    var outputs: [MLXArray] = []
    var windowSums: [MLXArray] = []

    for i in 0 ..< windowModLen {
        let outputStride: MLXArray = output[.stride(from: i, by: windowModLen), .ellipsis].reshaped([-1])
        let windowSumArray: MLXArray = totalWsquared[0 ..< outputStride.shape[0]]

        outputs.append(MLX.concatenated([
            MLXArray.zeros([i * hopLen]),
            outputStride,
            MLXArray.zeros([max(0, totalLength - i * hopLen - outputStride.shape[0])])
        ]))

        windowSums.append(MLX.concatenated([
            MLXArray.zeros([i * hopLen]),
            windowSumArray,
            MLXArray.zeros([max(0, totalLength - i * hopLen - windowSumArray.shape[0])])
        ]))
    }

    var reconstructed: MLXArray = outputs[0]
    var windowSum: MLXArray = windowSums[0]
    for i in 1 ..< windowModLen {
        reconstructed += outputs[i]
        windowSum += windowSums[i]
    }

    reconstructed =
    reconstructed[winLen / 2 ..< (reconstructed.shape[0] - winLen / 2)] /
    windowSum[winLen / 2 ..< (reconstructed.shape[0] - winLen / 2)]

    return reconstructed
}

internal class MLXSTFT {
    let filterLength: Int
    let hopLength: Int
    let winLength: Int
    let window: String

    var magnitude: MLXArray?
    var phase: MLXArray?

    init(filterLength: Int = 800, hopLength: Int = 200, winLength: Int = 800, window: String = "hann") {
        self.filterLength = filterLength
        self.hopLength = hopLength
        self.winLength = winLength
        self.window = window
    }

    func transform(inputData: MLXArray) -> (MLXArray, MLXArray) {
        var audioArray: MLXArray = inputData
        if audioArray.ndim == 1 {
            audioArray = audioArray.expandedDimensions(axis: 0)
        }

        var magnitudes: [MLXArray] = []
        var phases: [MLXArray] = []

        for batchIdx in 0 ..< audioArray.shape[0] {
            // Compute STFT
            let stft: MLXArray = mlxStft(
                x: audioArray[batchIdx],
                nFft: filterLength,
                hopLength: hopLength,
                winLength: winLength,
                window: window,
                center: true,
                padMode: "reflect"
            )

            let magnitude: MLXArray = MLX.abs(stft)

            // Replaces np.angle()
            let phase: MLXArray = MLX.atan2(stft.imaginaryPart(), stft.realPart())

            magnitudes.append(magnitude)
            phases.append(phase)
        }

        let magnitudesStacked: MLXArray = MLX.stacked(magnitudes, axis: 0)
        let phasesStacked: MLXArray = MLX.stacked(phases, axis: 0)

        return (magnitudesStacked, phasesStacked)
    }

    func inverse(magnitude: MLXArray, phase: MLXArray) -> MLXArray {
        var reconstructed: [MLXArray] = []

        for batchIdx in 0 ..< magnitude.shape[0] {
            let phaseCont: MLXArray = unwrap(p: phase[batchIdx])

            // Combine magnitude and phase
            let stft: MLXArray = magnitude[batchIdx] * MLX.exp(MLXArray(real: 0, imaginary: 1) * phaseCont)

            // Inverse STFT
            let audio: MLXArray = mlxIstft(
                x: stft,
                hopLength: hopLength,
                winLength: winLength,
                window: window
            )
            reconstructed.append(audio)
        }

        let reconstructedStacked: MLXArray = MLX.stacked(reconstructed, axis: 0)
        return reconstructedStacked.expandedDimensions(axis: 1)
    }

    func callAsFunction(inputData: MLXArray) -> MLXArray {
        let (mag, ph): (MLXArray, MLXArray) = transform(inputData: inputData)
        magnitude = mag
        phase = ph
        let reconstruction: MLXArray = inverse(magnitude: mag, phase: ph)
        return reconstruction.expandedDimensions(axis: -2)
    }

    deinit {
        // No explicit cleanup needed
    }
}
