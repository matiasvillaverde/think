import Accelerate
import CoreML

@available(iOS 16.2, macOS 13.1, *)
public protocol Scheduler {
    /// Number of diffusion steps performed during training
    var trainStepCount: Int { get }

    /// Number of inference steps to be performed
    var inferenceStepCount: Int { get }

    /// Training diffusion time steps index by inference time step
    var timeSteps: [Int] { get }

    /// Training diffusion time steps index by inference time step
    func calculateTimesteps(strength: Float?) -> [Int]

    /// Schedule of betas which controls the amount of noise added at each timestep
    var betas: [Float] { get }

    /// 1 - betas
    var alphas: [Float] { get }

    /// Cached cumulative product of alphas
    var alphasCumProd: [Float] { get }

    /// Standard deviation of the initial noise distribution
    var initNoiseSigma: Float { get }

    /// Denoised latents
    var modelOutputs: [MLShapedArray<Float32>] { get }

    /// Compute a de-noised image sample and step scheduler state
    ///
    /// - Parameters:
    ///   - output: The predicted residual noise output of learned diffusion model
    ///   - timeStep: The current time step in the diffusion chain
    ///   - sample: The current input sample to the diffusion model
    /// - Returns: Predicted de-noised sample at the previous time step
    /// - Postcondition: The scheduler state is updated.
    ///   The state holds the current sample and history of model output noise residuals
    func step(
        output: MLShapedArray<Float32>,
        timeStep t: Int,
        sample s: MLShapedArray<Float32>
    ) -> MLShapedArray<Float32>
}

@available(iOS 16.2, macOS 13.1, *)
public extension Scheduler {
    var initNoiseSigma: Float { 1 }
}

@available(iOS 16.2, macOS 13.1, *)
public extension Scheduler {
    /// Compute weighted sum of shaped arrays of equal shapes
    ///
    /// - Parameters:
    ///   - weights: The weights each array is multiplied by
    ///   - values: The arrays to be weighted and summed
    /// - Returns: sum_i weights[i]*values[i]
    func weightedSum(_ weights: [Double], _ values: [MLShapedArray<Float32>]) -> MLShapedArray<Float32> {
        let scalarCount = values.first!.scalarCount
        assert(weights.count > 1 && values.count == weights.count)
        assert(values.allSatisfy { $0.scalarCount == scalarCount })

        return MLShapedArray(unsafeUninitializedShape: values.first!.shape) { scalars, _ in
            scalars.initialize(repeating: 0.0)
            for i in 0 ..< values.count {
                let w = Float(weights[i])
                values[i].withUnsafeShapedBufferPointer { buffer, _, _ in
                    assert(buffer.count == scalarCount)
                    // scalars[j] += w * values[i].scalars[j]
                    vDSP_vsma(
                        buffer.baseAddress!, 1, [w],
                        scalars.baseAddress!, 1,
                        scalars.baseAddress!, 1,
                        vDSP_Length(scalarCount)
                    )
                }
            }
        }
    }

    func addNoise(
        originalSample: MLShapedArray<Float32>,
        noise: [MLShapedArray<Float32>],
        strength: Float
    ) -> [MLShapedArray<Float32>] {
        let startStep = max(inferenceStepCount - Int(Float(inferenceStepCount) * strength), 0)
        let alphaProdt = alphasCumProd[timeSteps[startStep]]
        let betaProdt = 1 - alphaProdt
        let sqrtAlphaProdt = sqrt(alphaProdt)
        let sqrtBetaProdt = sqrt(betaProdt)

        return noise.map {
            weightedSum(
                [Double(sqrtAlphaProdt), Double(sqrtBetaProdt)],
                [originalSample, $0]
            )
        }
    }
}

// MARK: - Timesteps

@available(iOS 16.2, macOS 13.1, *)
public extension Scheduler {
    func calculateTimesteps(strength: Float?) -> [Int] {
        guard let strength else { return timeSteps }
        let startStep = max(inferenceStepCount - Int(Float(inferenceStepCount) * strength), 0)
        return Array(timeSteps[startStep...])
    }
}

// MARK: - BetaSchedule

/// How to map a beta range to a sequence of betas to step over
@available(iOS 16.2, macOS 13.1, *)
public enum BetaSchedule {
    /// Linear stepping between start and end
    case linear
    /// Steps using linspace(sqrt(start),sqrt(end))^2
    case scaledLinear
}
