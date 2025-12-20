import Accelerate
import CoreML

/// How to space timesteps for inference
public enum TimeStepSpacing {
    case karras
    case leading
    case linspace
}

/// Configuration result for time steps
@available(iOS 16.2, macOS 13.1, *)
struct TimeStepConfiguration {
    let timeSteps: [Int]
    let alpha_t: [Float]
    let sigma_t: [Float]
    let usingKarrasSigmas: Bool
}

/// Handles beta and alpha calculations for the scheduler
@available(iOS 16.2, macOS 13.1, *)
struct BetaAlphaCalculator {
    /// Configures beta values based on the specified schedule
    func configureBetas(
        betaSchedule: BetaSchedule,
        betaStart: Float,
        betaEnd: Float,
        trainStepCount: Int
    ) -> [Float] {
        switch betaSchedule {
        case .linear:
            return linspace(betaStart, betaEnd, trainStepCount)
        case .scaledLinear:
            return linspace(pow(betaStart, 0.5), pow(betaEnd, 0.5), trainStepCount).map { $0 * $0 }
        }
    }

    /// Computes cumulative product of alphas
    func computeAlphasCumProd(alphas: [Float]) -> [Float] {
        var alphasCumProd = alphas
        for i in 1..<alphasCumProd.count {
            alphasCumProd[i] *= alphasCumProd[i - 1]
        }
        return alphasCumProd
    }
}

/// Handles time step configuration for different spacing methods
@available(iOS 16.2, macOS 13.1, *)
struct TimeStepConfigurator {
    /// Configures time steps based on the specified spacing method
    func configureTimeSteps(
        timeStepSpacing: TimeStepSpacing,
        stepCount: Int,
        trainStepCount: Int,
        alphasCumProd: [Float]
    ) -> TimeStepConfiguration {
        switch timeStepSpacing {
        case .linspace:
            return configureLinspaceTimeSteps(
                stepCount: stepCount,
                trainStepCount: trainStepCount,
                alphasCumProd: alphasCumProd
            )
        case .leading:
            return configureLeadingTimeSteps(
                stepCount: stepCount,
                trainStepCount: trainStepCount,
                alphasCumProd: alphasCumProd
            )
        case .karras:
            return configureKarrasTimeSteps(stepCount: stepCount, alphasCumProd: alphasCumProd)
        }
    }

    /// Configures time steps using linspace method
    private func configureLinspaceTimeSteps(
        stepCount: Int,
        trainStepCount: Int,
        alphasCumProd: [Float]
    ) -> TimeStepConfiguration {
        let timeSteps = linspace(0, Float(trainStepCount - 1), stepCount + 1)
            .dropFirst().reversed().map { Int(round($0)) }
        let alpha_t = vForce.sqrt(alphasCumProd)
        let sigma_t = vForce.sqrt(
            vDSP.subtract([Float](repeating: 1, count: alphasCumProd.count), alphasCumProd)
        )
        return TimeStepConfiguration(
            timeSteps: timeSteps,
            alpha_t: alpha_t,
            sigma_t: sigma_t,
            usingKarrasSigmas: false
        )
    }

    /// Configures time steps using leading method
    private func configureLeadingTimeSteps(
        stepCount: Int,
        trainStepCount: Int,
        alphasCumProd: [Float]
    ) -> TimeStepConfiguration {
        let lastTimeStep = trainStepCount - 1
        let stepRatio = lastTimeStep / (stepCount + 1)
        let timeSteps = Array((0...stepCount).map { 1 + $0 * stepRatio }.dropFirst().reversed())
        let alpha_t = vForce.sqrt(alphasCumProd)
        let sigma_t = vForce.sqrt(
            vDSP.subtract([Float](repeating: 1, count: alphasCumProd.count), alphasCumProd)
        )
        return TimeStepConfiguration(
            timeSteps: timeSteps,
            alpha_t: alpha_t,
            sigma_t: sigma_t,
            usingKarrasSigmas: false
        )
    }

    /// Configures time steps using Karras sigmas method
    private func configureKarrasTimeSteps(
        stepCount: Int,
        alphasCumProd: [Float]
    ) -> TimeStepConfiguration {
        let scaled = vDSP.multiply(
            subtraction: ([Float](repeating: 1, count: alphasCumProd.count), alphasCumProd),
            subtraction: (
                vDSP.divide(1, alphasCumProd),
                [Float](repeating: 0, count: alphasCumProd.count)
            )
        )
        let sigmas = vForce.sqrt(scaled)
        let logSigmas = sigmas.map { log($0) }

        guard let sigmaMin = sigmas.first,
            let sigmaMax = sigmas.last else {
            fatalError("Sigmas array is empty")
        }

        let rho: Float = 7
        let ramp = linspace(0, 1, stepCount)
        let minInvRho = pow(sigmaMin, (1 / rho))
        let maxInvRho = pow(sigmaMax, (1 / rho))

        var karrasSigmas = ramp.map { pow(maxInvRho + $0 * (minInvRho - maxInvRho), rho) }
        let karrasTimeSteps = karrasSigmas.map { sigmaToTimestep(sigma: $0, logSigmas: logSigmas) }

        if let lastSigma = karrasSigmas.last {
            karrasSigmas.append(lastSigma)
        }

        let alpha_t = vDSP.divide(1, vForce.sqrt(vDSP.add(1, vDSP.square(karrasSigmas))))
        let sigma_t = vDSP.multiply(karrasSigmas, alpha_t)

        return TimeStepConfiguration(
            timeSteps: karrasTimeSteps,
            alpha_t: alpha_t,
            sigma_t: sigma_t,
            usingKarrasSigmas: true
        )
    }
}

func sigmaToTimestep(sigma: Float, logSigmas: [Float]) -> Int {
    let logSigma = log(sigma)
    let dists = logSigmas.map { logSigma - $0 }

    // last index that is not negative, clipped to last index - 1
    var lowIndex = dists.reduce(-1) { partialResult, dist in
        dist >= 0 && partialResult < dists.endIndex - 2 ? partialResult + 1 : partialResult
    }
    lowIndex = max(lowIndex, 0)
    let highIndex = lowIndex + 1

    let low = logSigmas[lowIndex]
    let high = logSigmas[highIndex]

    // Interpolate sigmas
    let weight = ((low - logSigma) / (low - high)).clipped(to: 0...1)

    // transform interpolated value to time range
    let interpolatedTime = (1 - weight) * Float(lowIndex) + weight * Float(highIndex)
    return Int(round(interpolatedTime))
}

extension FloatingPoint {
    func clipped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
