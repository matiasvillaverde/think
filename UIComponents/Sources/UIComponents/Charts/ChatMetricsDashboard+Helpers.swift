import Database
import Foundation
#if canImport(UIKit)
    import UIKit
#endif

extension ChatMetricsDashboard {
    // MARK: - Layout Properties

    var adaptivePadding: CGFloat {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return Constants.iPhonePadding
            }
        #endif
        return Constants.defaultPadding
    }

    // MARK: - Filter Properties

    var hasMultipleMessages: Bool {
        metrics.count >= Constants.messageCountThreshold
    }

    // MARK: - Computed Properties

    var averageTokensPerSecond: String {
        let avg: Double = filteredMetrics
            .map(\.tokensPerSecond)
            .reduce(0, +) / Double(max(filteredMetrics.count, 1))
        return String(format: "%.1f", avg)
    }

    var totalTokens: Int {
        filteredMetrics
            .map { $0.promptTokens + $0.generatedTokens }
            .reduce(0, +)
    }

    var averageResponseTime: Double {
        let total: Double = filteredMetrics
            .map(\.totalTime)
            .reduce(0, +)
        return total / Double(max(filteredMetrics.count, 1))
    }

    var averageContextUsage: Double {
        let usages: [Double] = filteredMetrics.compactMap { metric in
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
            return 0
        }
        return usages.reduce(0, +) / Double(usages.count)
    }

    var hasQualityMetrics: Bool {
        filteredMetrics.contains { metric in
            metric.entropy != nil || metric.repetitionRate != nil
        }
    }

    var hasMultipleModels: Bool {
        let models: Set<String> = Set(filteredMetrics.compactMap(\.modelName))
        return models.count > 1
    }

    var hasPerplexityData: Bool {
        filteredMetrics.contains { $0.perplexity != nil }
    }
}
