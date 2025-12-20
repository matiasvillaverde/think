import Accelerate
import CoreML

/// A scheduler used to compute a de-noised image
///
///  This implementation matches:
///  [Hugging Face Diffusers DPMSolverMultistepScheduler]
///  (https://github.com/huggingface/diffusers/blob/main/src/diffusers/schedulers/scheduling_dpmsolver_multistep.py)
///
/// It uses the DPM-Solver++ algorithm:
/// [code](https://github.com/LuChengTHU/dpm-solver)
/// [paper](https://arxiv.org/abs/2211.01095).
/// Limitations:
///  - Only implemented for DPM-Solver++ algorithm (not DPM-Solver).
///  - Second order only.
///  - Assumes the model predicts epsilon.
///  - No dynamic thresholding.
///  - `midpoint` solver algorithm.
@available(iOS 16.2, macOS 13.1, *)
public final class DPMSolverMultistepScheduler: Scheduler {
    /// Number of diffusion steps used during training
    public let trainStepCount: Int

    /// Number of inference steps for denoising
    public let inferenceStepCount: Int
    /// Beta schedule values for each timestep
    public let betas: [Float]

    /// Alpha values computed as (1 - beta) for each timestep
    public let alphas: [Float]

    /// Cumulative product of alphas
    public let alphasCumProd: [Float]

    /// Time steps used for inference
    public let timeSteps: [Int]

    /// Alpha values for the DPM-Solver++ algorithm
    public let alpha_t: [Float]

    /// Sigma values for the DPM-Solver++ algorithm
    public let sigma_t: [Float]

    /// Lambda values for the DPM-Solver++ algorithm
    public let lambda_t: [Float]

    /// Order of the solver (always 2 for this implementation)
    public let solverOrder: Int = 2
    private(set) var lowerOrderStepped: Int = 0

    private var usingKarrasSigmas: Bool = false

    /// Whether to use lower-order solvers in the final steps. Only valid for less than 15 inference steps.
    /// We empirically find this trick can stabilize the sampling of DPM-Solver, especially with 10 or fewer steps.
    public let useLowerOrderFinal: Bool = true

    /// Stores the last solverOrder (2) model outputs for multi-step updates
    public private(set) var modelOutputs: [MLShapedArray<Float32>] = []

    /// Create a scheduler that uses a second order DPM-Solver++ algorithm.
    ///
    /// - Parameters:
    ///   - stepCount: Number of inference steps to schedule
    ///   - trainStepCount: Number of training diffusion steps
    ///   - betaSchedule: Method to schedule betas from betaStart to betaEnd
    ///   - betaStart: The starting value of beta for inference
    ///   - betaEnd: The end value for beta for inference
    ///   - timeStepSpacing: How to space time steps
    /// - Returns: A scheduler ready for its first step
    public init(
        stepCount: Int = 50,
        trainStepCount: Int = 1000,
        betaSchedule: BetaSchedule = .scaledLinear,
        betaStart: Float = 0.000_85,
        betaEnd: Float = 0.012,
        timeStepSpacing: TimeStepSpacing = .linspace
    ) {
        self.trainStepCount = trainStepCount
        self.inferenceStepCount = stepCount

        // Configure betas and alphas
        let betaAlphaCalculator = BetaAlphaCalculator()
        self.betas = betaAlphaCalculator.configureBetas(
            betaSchedule: betaSchedule,
            betaStart: betaStart,
            betaEnd: betaEnd,
            trainStepCount: trainStepCount
        )
        self.alphas = betas.map { 1.0 - $0 }
        self.alphasCumProd = betaAlphaCalculator.computeAlphasCumProd(alphas: alphas)

        // Configure time steps based on spacing method
        let timeStepConfigurator = TimeStepConfigurator()
        let timeStepConfig = timeStepConfigurator.configureTimeSteps(
            timeStepSpacing: timeStepSpacing,
            stepCount: stepCount,
            trainStepCount: trainStepCount,
            alphasCumProd: alphasCumProd
        )

        self.timeSteps = timeStepConfig.timeSteps
        self.alpha_t = timeStepConfig.alpha_t
        self.sigma_t = timeStepConfig.sigma_t
        self.usingKarrasSigmas = timeStepConfig.usingKarrasSigmas

        self.lambda_t = zip(self.alpha_t, self.sigma_t).map { alpha, sigma in log(alpha) - log(sigma) }
    }

    func timestepToIndex(_ timestep: Int) -> Int {
        guard usingKarrasSigmas else {
            return timestep
        }
        return self.timeSteps.firstIndex(of: timestep) ?? 0
    }

    /// Convert the model output to the corresponding type the algorithm needs.
    /// This implementation is for second-order DPM-Solver++ assuming epsilon prediction.
    func convertModelOutput(
        modelOutput: MLShapedArray<Float32>,
        timestep: Int,
        sample: MLShapedArray<Float32>
    ) -> MLShapedArray<Float32> {
        assert(modelOutput.scalarCount == sample.scalarCount)
        let scalarCount = modelOutput.scalarCount
        let sigmaIndex = timestepToIndex(timestep)
        let (alpha_t, sigma_t) = (self.alpha_t[sigmaIndex], self.sigma_t[sigmaIndex])

        return MLShapedArray(unsafeUninitializedShape: modelOutput.shape) { scalars, _ in
            assert(scalars.count == scalarCount)
            modelOutput.withUnsafeShapedBufferPointer { modelOutput, _, _ in
                sample.withUnsafeShapedBufferPointer { sample, _, _ in
                    for i in 0 ..< scalarCount {
                        scalars.initializeElement(at: i, to: (sample[i] - modelOutput[i] * sigma_t) / alpha_t)
                    }
                }
            }
        }
    }

    /// One step for the first-order DPM-Solver (equivalent to DDIM).
    /// See https://arxiv.org/abs/2206.00927 for the detailed derivation.
    /// var names and code structure mostly follow
    /// https://github.com/huggingface/diffusers/blob/main/src/diffusers/schedulers/scheduling_dpmsolver_multistep.py
    func firstOrderUpdate(
        modelOutput: MLShapedArray<Float32>,
        timestep: Int,
        prevTimestep: Int,
        sample: MLShapedArray<Float32>
    ) -> MLShapedArray<Float32> {
        let prevIndex = timestepToIndex(prevTimestep)
        let currIndex = timestepToIndex(timestep)
        let (p_lambda_t, lambda_s) = (Double(lambda_t[prevIndex]), Double(lambda_t[currIndex]))
        let p_alpha_t = Double(alpha_t[prevIndex])
        let (p_sigma_t, sigma_s) = (Double(sigma_t[prevIndex]), Double(sigma_t[currIndex]))
        let stepSize = p_lambda_t - lambda_s
        // x_t = (sigma_t / sigma_s) * sample - (alpha_t * (torch.exp(-h) - 1.0)) * model_output
        return weightedSum(
            [p_sigma_t / sigma_s, -p_alpha_t * (exp(-stepSize) - 1)],
            [sample, modelOutput]
        )
    }

    /// One step for the second-order multistep DPM-Solver++ algorithm, using the midpoint method.
    /// var names and code structure mostly follow
    /// https://github.com/huggingface/diffusers/blob/main/src/diffusers/schedulers/scheduling_dpmsolver_multistep.py
    func secondOrderUpdate(
        modelOutputs: [MLShapedArray<Float32>],
        timesteps: [Int],
        prevTimestep: Int,
        sample: MLShapedArray<Float32>
    ) -> MLShapedArray<Float32> {
        let (s0, s1) = (timesteps[back: 1], timesteps[back: 2])
        let (m0, m1) = (modelOutputs[back: 1], modelOutputs[back: 2])
        let (p_lambda_t, lambda_s0, lambda_s1) = (
            Double(lambda_t[timestepToIndex(prevTimestep)]),
            Double(lambda_t[timestepToIndex(s0)]),
            Double(lambda_t[timestepToIndex(s1)])
        )
        let p_alpha_t = Double(alpha_t[timestepToIndex(prevTimestep)])
        let (p_sigma_t, sigma_s0) = (
            Double(sigma_t[timestepToIndex(prevTimestep)]),
            Double(sigma_t[timestepToIndex(s0)])
        )
        let (stepSize, h_0) = (p_lambda_t - lambda_s0, lambda_s0 - lambda_s1)
        let r0 = h_0 / stepSize
        let d0 = m0

        // D1 = (1.0 / r0) * (m0 - m1)
        let d1 = weightedSum(
            [1 / r0, -1 / r0],
            [m0, m1]
        )

        // See https://arxiv.org/abs/2211.01095 for detailed derivations
        // x_t = (
        //     (sigma_t / sigma_s0) * sample
        //     - (alpha_t * (torch.exp(-h) - 1.0)) * D0
        //     - 0.5 * (alpha_t * (torch.exp(-h) - 1.0)) * D1
        // )
        return weightedSum(
            [p_sigma_t / sigma_s0, -p_alpha_t * (exp(-stepSize) - 1), -0.5 * p_alpha_t * (exp(-stepSize) - 1)],
            [sample, d0, d1]
        )
    }

    /// Performs a single denoising step
    ///
    /// - Parameters:
    ///   - output: Model output from the diffusion model
    ///   - timeStep: Current time step
    ///   - sample: Current sample being denoised
    /// - Returns: Denoised sample for the next step
    public func step(
        output: MLShapedArray<Float32>,
        timeStep: Int,
        sample: MLShapedArray<Float32>
    ) -> MLShapedArray<Float32> {
        let stepIndex = timeSteps.firstIndex(of: timeStep) ?? timeSteps.count - 1
        let prevTimestep = stepIndex == timeSteps.count - 1 ? 0 : timeSteps[stepIndex + 1]

        let lowerOrderFinal = useLowerOrderFinal && stepIndex == timeSteps.count - 1 && timeSteps.count < 15
        let lowerOrderSecond = useLowerOrderFinal && stepIndex == timeSteps.count - 2 && timeSteps.count < 15
        let lowerOrder = lowerOrderStepped < 1 || lowerOrderFinal || lowerOrderSecond

        let modelOutput = convertModelOutput(modelOutput: output, timestep: timeStep, sample: sample)
        if modelOutputs.count == solverOrder { modelOutputs.removeFirst() }
        modelOutputs.append(modelOutput)

        let prevSample: MLShapedArray<Float32>
        if lowerOrder {
            prevSample = firstOrderUpdate(
                modelOutput: modelOutput,
                timestep: timeStep,
                prevTimestep: prevTimestep,
                sample: sample
            )
        } else {
            prevSample = secondOrderUpdate(
                modelOutputs: modelOutputs,
                timesteps: [timeSteps[stepIndex - 1], timeStep],
                prevTimestep: prevTimestep,
                sample: sample
            )
        }
        if lowerOrderStepped < solverOrder {
            lowerOrderStepped += 1
        }

        return prevSample
    }

    deinit {
        // Cleanup if needed
    }
}
