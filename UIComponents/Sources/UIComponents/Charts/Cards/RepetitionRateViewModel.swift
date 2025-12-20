import Database
import Foundation
import SwiftUI

// MARK: - Supporting Types

public enum NGramLevel: String, CaseIterable {
    case bigram = "2-gram"
    case fourgram = "4-gram"
    case trigram = "3-gram"
    case unigram = "1-gram"

    var value: Int {
        switch self {
        case .unigram:
            1

        case .bigram:
            Constants.bigramValue

        case .trigram:
            Constants.trigramValue

        case .fourgram:
            Constants.fourgramValue
        }
    }

    private enum Constants {
        static let bigramValue: Int = 2
        static let trigramValue: Int = 3
        static let fourgramValue: Int = 4
    }
}

internal struct RepetitionData: Identifiable {
    let id: UUID = .init()
    let index: Int
    let rate: Double
    let timestamp: Date
}

internal struct TrendDirection {
    let text: String
    let icon: String
    let color: Color
}

// MARK: - View Model

internal final class RepetitionRateViewModel: ObservableObject {
    let metrics: [Metrics]

    private enum Constants {
        static let maxDataPoints: Int = 30
        static let baseMod: Int = 100
        static let percentageDivisor: Double = 100.0
        static let stableThreshold: Double = 0.05
        static let minSampleSize: Int = 2
        static let warningThreshold: Double = 0.5
        static let baselineThreshold: Double = 0.3
    }

    init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    deinit {
        // Cleanup if needed
    }

    func repetitionData(for nGramLevel: NGramLevel, maxPoints: Int) -> [RepetitionData] {
        let suffix: [Metrics] = Array(metrics.suffix(maxPoints))
        return suffix.enumerated().map { index, metric in
            RepetitionData(
                index: index,
                rate: calculateRepetitionRate(for: metric, nGramLevel: nGramLevel),
                timestamp: metric.createdAt
            )
        }
    }

    private func calculateRepetitionRate(for metric: Metrics, nGramLevel: NGramLevel) -> Double {
        // Simulate repetition rate based on n-gram level
        // In a real implementation, this would be calculated from actual text analysis
        let baseRate: Double = Double(metric.generatedTokens % Constants.baseMod) /
            Constants.percentageDivisor
        let ngramFactor: Double = 1.0 / Double(nGramLevel.value)
        return min(baseRate * ngramFactor, 1.0)
    }

    func averageRate(for data: [RepetitionData]) -> Double {
        guard !data.isEmpty else {
            return 0
        }
        return data.map(\.rate).reduce(0, +) / Double(data.count)
    }

    func peakRate(for data: [RepetitionData]) -> Double {
        data.map(\.rate).max() ?? 0
    }

    func trendDirection(for data: [RepetitionData]) -> TrendDirection {
        guard data.count >= Constants.minSampleSize else {
            return TrendDirection(text: "Stable", icon: "minus", color: .gray)
        }

        let sampleSize: Int = 5
        let recentAverage: Double = averageRate(for: Array(data.suffix(sampleSize)))
        let overallAverage: Double = averageRate(for: data)
        let difference: Double = recentAverage - overallAverage

        if abs(difference) < Constants.stableThreshold {
            return TrendDirection(text: "Stable", icon: "minus", color: .gray)
        }
        if difference > 0 {
            return TrendDirection(text: "Rising", icon: "arrow.up.right", color: .orange)
        }
        return TrendDirection(text: "Falling", icon: "arrow.down.right", color: .green)
    }

    func rateColor(for rate: Double) -> Color {
        if rate > Constants.warningThreshold {
            return .red
        }
        if rate > Constants.baselineThreshold {
            return .orange
        }
        return .green
    }

    func warningThreshold() -> Double {
        Constants.warningThreshold
    }

    func baselineThreshold() -> Double {
        Constants.baselineThreshold
    }
}
