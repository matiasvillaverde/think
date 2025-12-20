import Charts
import Database
import SwiftUI

// MARK: - Token Processing Configuration

internal struct TokenProcessingConfig {
    let maxMetricsCount: Int
    let maxTokensPerMetric: Int
    let minProbability: Double
    let maxProbability: Double
    let minTokenLength: Int
    let maxTokenLength: Int
    let maxDataPoints: Int
    let highThreshold: Double = 0.7
    let lowThreshold: Double = 0.3
}

// MARK: - Token Probability View Model

/// View model for token probability scatter plot card
internal final class TokenProbabilityViewModel: ObservableObject {
    private let metrics: [Metrics]

    init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    deinit {
        // Cleanup if needed
    }

    // MARK: - Data Processing

    func getTokenProbabilities(config: TokenProcessingConfig) -> [TokenProbability] {
        var probabilities: [TokenProbability] = []

        for metric in metrics.suffix(config.maxMetricsCount) {
            // Simulate token probabilities
            let tokenCount: Int = min(metric.generatedTokens, config.maxTokensPerMetric)
            for _ in 0 ..< tokenCount {
                let probability: Double = Double.random(
                    in: config.minProbability ... config.maxProbability
                )
                probabilities.append(TokenProbability(
                    tokenIndex: probabilities.count,
                    probability: probability,
                    tokenLength: Int.random(
                        in: config.minTokenLength ... config.maxTokenLength
                    ),
                    metricId: metric.id.uuidString,
                    color: probabilityColor(
                        for: probability,
                        highThreshold: config.highThreshold,
                        lowThreshold: config.lowThreshold
                    )
                ))
            }
        }

        return Array(probabilities.suffix(config.maxDataPoints))
    }

    func filteredProbabilities(
        from tokenProbabilities: [TokenProbability],
        selectedType: TokenType,
        highThreshold: Double,
        lowThreshold: Double
    ) -> [TokenProbability] {
        tokenProbabilities.filter { token in
            selectedType.filter(
                token.probability,
                highThreshold: highThreshold,
                lowThreshold: lowThreshold
            )
        }
    }

    func probabilityColor(
        for probability: Double,
        highThreshold: Double,
        lowThreshold: Double
    ) -> Color {
        switch probability {
        case highThreshold ... 1.0:
            .green

        case lowThreshold ..< highThreshold:
            .orange

        default:
            .red
        }
    }

    func trendValue(
        at index: Int,
        filteredProbabilities: [TokenProbability],
        defaultProbability: Double
    ) -> Double {
        guard !filteredProbabilities.isEmpty else {
            return defaultProbability
        }

        let avgProb: Double = averageProbability(for: filteredProbabilities)
        let slope: Double = (filteredProbabilities.last?.probability ?? avgProb) -
            (filteredProbabilities.first?.probability ?? avgProb)
        let range: Double = Double(filteredProbabilities.count)

        guard range > 0 else {
            return avgProb
        }

        let normalizedIndex: Double = Double(index) / range
        return avgProb + (slope * normalizedIndex)
    }

    func averageProbability(for probabilities: [TokenProbability]) -> Double {
        guard !probabilities.isEmpty else {
            return 0
        }
        return probabilities.map(\.probability).reduce(0, +) /
            Double(probabilities.count)
    }

    func highConfidencePercentage(
        for tokenProbabilities: [TokenProbability],
        highThreshold: Double,
        percentageMultiplier: Double
    ) -> Double {
        guard !tokenProbabilities.isEmpty else {
            return 0
        }
        let highCount: Int = tokenProbabilities.count { point in
            point.probability > highThreshold
        }
        return Double(highCount) / Double(tokenProbabilities.count) * percentageMultiplier
    }

    func uncertaintyScore(
        for filteredProbabilities: [TokenProbability],
        exponentialPower: Double
    ) -> Double {
        let probabilities: [Double] = filteredProbabilities.map(\.probability)
        guard !probabilities.isEmpty else {
            return 0
        }

        let avgProb: Double = averageProbability(for: filteredProbabilities)
        let variance: Double = probabilities
            .map { prob in
                pow(prob - avgProb, exponentialPower)
            }
            .reduce(0, +) / Double(probabilities.count)
        return sqrt(variance)
    }

    func trendLineYValue(at position: Int, for data: [TokenProbability]) -> Double {
        let defaultProbability: Double = 0.5
        guard !data.isEmpty else {
            return defaultProbability
        }

        // Simple linear trend calculation
        let avgProb: Double = averageProbability(for: data)
        let positions: [Double] = data.map { Double($0.tokenIndex) }
        let probabilities: [Double] = data.map(\.probability)

        guard positions.count > 1 else {
            return avgProb
        }

        let meanX: Double = positions.reduce(0, +) / Double(positions.count)
        let meanY: Double = probabilities.reduce(0, +) / Double(probabilities.count)

        var numerator: Double = 0.0
        var denominator: Double = 0.0

        for index in 0..<positions.count {
            numerator += (positions[index] - meanX) * (probabilities[index] - meanY)
            denominator += (positions[index] - meanX) * (positions[index] - meanX)
        }

        let slope: Double = denominator != 0 ? numerator / denominator : 0
        let intercept: Double = meanY - slope * meanX

        return intercept + slope * Double(position)
    }
}
