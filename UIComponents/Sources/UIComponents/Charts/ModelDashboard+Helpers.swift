import Database
import Foundation

extension ModelDashboard {
    // MARK: - Computed Properties

    var averageTokensPerSecond: Double {
        let sum: Double = filteredMetrics.map(\.tokensPerSecond).reduce(0, +)
        return sum / Double(max(filteredMetrics.count, 1))
    }

    var totalGeneratedTokens: Int {
        filteredMetrics.map(\.generatedTokens).reduce(0, +)
    }

    var averageResponseTime: Double {
        let sum: Double = filteredMetrics.map(\.totalTime).reduce(0, +)
        return sum / Double(max(filteredMetrics.count, 1))
    }

    var uniqueChats: Int {
        let chatIds: [UUID] = filteredMetrics.compactMap { metric in
            metric.message?.chat?.id
        }
        return Set(chatIds).count
    }

    var averagePerplexity: Double? {
        let values: [Double] = filteredMetrics.compactMap(\.perplexity)
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }

    var averageContextUsage: Double? {
        let usages: [Double] = filteredMetrics.compactMap { metric -> Double? in
            guard
                let used = metric.contextTokensUsed,
                let windowSize = metric.contextWindowSize,
                windowSize > 0
            else {
                return nil
            }
            return Double(used) / Double(windowSize)
        }
        guard !usages.isEmpty else {
            return nil
        }
        return usages.reduce(0, +) / Double(usages.count)
    }

    var hasQualityMetrics: Bool {
        filteredMetrics.contains { metric in
            metric.perplexity != nil || metric.entropy != nil || metric.repetitionRate != nil
        }
    }

    var hasContextData: Bool {
        filteredMetrics.contains { metric in
            metric.contextTokensUsed != nil && metric.contextWindowSize != nil
        }
    }

    func calculateAverageSpeed(_ metrics: [Metrics]) -> Double {
        let sum: Double = metrics.map(\.tokensPerSecond).reduce(0, +)
        return sum / Double(max(metrics.count, 1))
    }

    func calculateTotalTokens(_ metrics: [Metrics]) -> Int {
        metrics.map { $0.promptTokens + $0.generatedTokens }.reduce(0, +)
    }

    func calculateAverageQuality(_ metrics: [Metrics]) -> Double? {
        let perplexities: [Double] = metrics.compactMap(\.perplexity)
        guard !perplexities.isEmpty else {
            return nil
        }
        return perplexities.reduce(0, +) / Double(perplexities.count)
    }

    func getDateRange() -> String? {
        guard
            let first = metrics.first?.createdAt,
            let last = metrics.last?.createdAt
        else {
            return nil
        }
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }
}
